import AVFoundation
import Foundation
import Observation

/// A live voice conversation with the patient: the student talks, the patient answers out loud in
/// real time, and either can cut in. Audio runs phone ↔ OpenAI (`LiveVoiceTransport`); this model
/// keeps the phase for the orb, pairs each question with its answer and hands the pair to the case
/// session to log, and ends the call when its time is up.
///
/// If a call can't start (no allowance left today, no connection), `begin` returns false and the
/// screen falls back to turn-by-turn voice (`VoiceController`).
@MainActor
@Observable
final class LiveVoice {
    private(set) var phase: VoiceController.Phase = .idle
    /// True from the tap until the patient can hear the student.
    private(set) var isConnecting = false
    /// 0…1 for the orb: the mic while the student talks, the patient's voice while they answer.
    private(set) var level: CGFloat = 0
    /// The patient's words so far in the current reply, revealed at about speaking pace: the API's
    /// text runs ahead of the audio, so showing it as it lands would put the caption seconds early.
    private(set) var caption = ""
    /// When the call ends on its own; nil until it's live.
    private(set) var endsAt: Date?

    var isActive: Bool { phase != .idle }

    private enum LIVE {
        static let levelGain = 2.2      // WebRTC levels run low (speech peaks near 0.3): lift them for the orb
        static let smoothing = 0.35     // new-sample weight
        static let captionHold: Duration = .seconds(1.5)   // a finished reply stays this long, then clears
    }

    /// The case session's side: open a call for an offer, log an exchange (true = the server ended
    /// the call), and close a call.
    @ObservationIgnored private let open: (String) async throws -> LiveCall
    @ObservationIgnored private let logTurn: (String, String, String) async -> Bool
    @ObservationIgnored private let close: (String) -> Void
    @ObservationIgnored private let makeTransport: () -> any LiveVoiceTransport
    /// Asks for the microphone (the system prompt the first time); tests answer it themselves.
    @ObservationIgnored private let micAllowed: () async -> Bool

    @ObservationIgnored private var transport: (any LiveVoiceTransport)?
    @ObservationIgnored private var callID: String?
    @ObservationIgnored private var pairer = LiveTurnPairer()
    @ObservationIgnored private var listening: Task<Void, Never>?
    @ObservationIgnored private var deadline: Task<Void, Never>?
    /// Exchanges still being logged. Hanging up waits for them, since the server refuses turns for a
    /// call that has already ended.
    @ObservationIgnored private var logging: [Task<Void, Never>] = []
    /// All of the current reply's words received so far; `caption` catches up with them.
    @ObservationIgnored private var spoken = ""
    @ObservationIgnored private var replyFinished = false
    @ObservationIgnored private var pacing: Task<Void, Never>?
    /// Time per character revealed: about how fast the patient's voice speaks.
    @ObservationIgnored private let captionPace: Duration

    init(open: @escaping (String) async throws -> LiveCall,
         logTurn: @escaping (String, String, String) async -> Bool,
         close: @escaping (String) -> Void,
         makeTransport: @escaping () -> any LiveVoiceTransport,
         micAllowed: @escaping () async -> Bool = { await AVAudioApplication.requestRecordPermission() },
         captionPace: Duration = .milliseconds(65)) {
        self.captionPace = captionPace
        self.micAllowed = micAllowed
        self.open = open
        self.logTurn = logTurn
        self.close = close
        self.makeTransport = makeTransport
    }

    /// Starts a call. False when it couldn't start, so the caller can fall back to turn-by-turn voice.
    func begin() async -> Bool {
        guard await micAllowed() else {
            phase = .unavailable("Microphone access is off. Turn it on in Settings › Privacy & Security › Microphone › Rounds.")
            return true   // shown here: the fallback would hit the same wall
        }
        phase = .thinking
        isConnecting = true
        let transport = makeTransport()
        self.transport = transport
        listen(to: transport)
        do {
            try await transport.connect { [weak self, open] offer in
                let call = try await open(offer)
                await self?.started(call)
                return call.answer
            }
            return true
        } catch {
            stop()
            return false
        }
    }

    /// Hangs up.
    func end() {
        if let callID {
            let pending = logging
            Task { [close] in
                for log in pending { await log.value }
                close(callID)
            }
        }
        stop()
    }

    /// Tap the orb while the patient talks: cut them off and take the floor.
    func interrupt() {
        guard phase == .patientSpeaking else { return }
        transport?.cutOffPatient()
        clearCaption()
        phase = .listening
    }

    // MARK: Call

    private func started(_ call: LiveCall) {
        callID = call.id
        let seconds = call.seconds
        endsAt = .now.addingTimeInterval(TimeInterval(seconds))
        deadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finish("This live call reached its time limit. Tap the mic to start another.")
        }
    }

    private func listen(to transport: any LiveVoiceTransport) {
        listening = Task { [weak self] in
            for await event in transport.events {
                guard let self, !Task.isCancelled else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: LiveVoiceEvent) {
        switch event {
        case .ready:
            isConnecting = false
            phase = .listening
        case .studentStartedSpeaking:
            // Talking over the patient stops them server-side; the half-said line just ends here.
            clearCaption()
            phase = .listening
        case .studentStoppedSpeaking:
            phase = .thinking
        case .studentSaid(let text):
            if let turn = pairer.studentSaid(text) { log(turn) }
        case .patientWords(let words):
            phase = .patientSpeaking
            if replyFinished { clearCaption() }   // a new reply starts its own line
            spoken += words
            paceCaption()
        case .patientFinished(let reply):
            replyFinished = true
            if phase == .patientSpeaking || phase == .thinking { phase = .listening }
            if let turn = pairer.patientFinished(reply) { log(turn) }
        case .levels(let mic, let patient):
            let raw = phase == .patientSpeaking ? patient : mic
            let sample = CGFloat(min(1, raw * LIVE.levelGain))
            level = level * (1 - LIVE.smoothing) + sample * LIVE.smoothing
        case .disconnected:
            finish("The live call dropped. Tap the mic to reconnect.")
        case .failed(let message, let fatal):
            if fatal { finish("Live voice stopped: \(message)") }
        }
    }

    /// Reveals `spoken` one character at a time until it's all shown; a finished reply then stays a
    /// moment and clears.
    private func paceCaption() {
        guard pacing == nil else { return }
        pacing = Task { [weak self] in
            while let self, !Task.isCancelled {
                if self.caption.count < self.spoken.count {
                    self.caption = String(self.spoken.prefix(self.caption.count + 1))
                    try? await Task.sleep(for: self.captionPace)
                } else if self.replyFinished {
                    try? await Task.sleep(for: LIVE.captionHold)
                    if !Task.isCancelled { self.caption = ""; self.spoken = "" }
                    break
                } else {
                    try? await Task.sleep(for: self.captionPace)
                }
            }
            self?.pacing = nil
        }
    }

    private func clearCaption() {
        pacing?.cancel(); pacing = nil
        spoken = ""
        caption = ""
        replyFinished = false
    }

    private func log(_ turn: (question: String, reply: String)) {
        guard let callID else { return }
        logging.append(Task { [weak self, logTurn] in
            let ended = await logTurn(callID, turn.question, turn.reply)
            if ended { self?.finish("The live call ended. You can still type, examine and order tests.") }
        })
    }

    /// Ends the call and leaves a message on the panel (the student closes it with ✕).
    private func finish(_ message: String) {
        guard isActive else { return }
        end()
        phase = .unavailable(message)
    }

    private func stop() {
        listening?.cancel(); listening = nil
        deadline?.cancel(); deadline = nil
        transport?.disconnect(); transport = nil
        callID = nil
        endsAt = nil
        pairer = LiveTurnPairer()
        logging = []
        clearCaption()
        level = 0
        isConnecting = false
        phase = .idle
    }

    #if DEBUG
    func debugPin(_ phase: VoiceController.Phase, level: CGFloat, caption: String = "") {
        self.phase = phase; self.level = level; self.caption = caption
        endsAt = .now.addingTimeInterval(240)
    }
    #endif
}
