import SwiftUI
import AVFoundation
import Speech
import Observation

/// Turn-taking voice conversation with the patient.
/// You speak (mic level + live transcript) → silence ends your turn → patient answers aloud → your turn again.
@Observable
final class VoiceController: NSObject, AVSpeechSynthesizerDelegate {
    enum Phase: Equatable {
        case idle
        case listening         // your turn
        case thinking          // question sent, waiting on the patient
        case patientSpeaking   // patient answering aloud
        case unavailable(String)
    }

    private enum VOICE {
        static let silenceToSend: TimeInterval = 1.4  // quiet this long after speaking → send
        static let levelFloorDb: Float = -50          // dB mapped to level 0
        static let levelRangeDb: Float = 40           // dB span mapped to 0…1
        static let smoothing: CGFloat = 0.35          // new-sample weight
        static let slowestRate: Float = 0.35         // Settings speed 0
        static let fastestRate: Float = 0.65         // Settings speed 1; 0.5 in between is the natural rate
        static let speechPitch: Float = 0.9
    }

    private(set) var phase: Phase = .idle
    private(set) var level: CGFloat = 0          // 0…1, mic level when listening, word pulses when patient speaks
    private(set) var transcript = ""
    var onUtterance: ((String) -> Void)?

    var isActive: Bool { phase != .idle }

    private let engine = AVAudioEngine()
    /// The phone's own language if speech recognition supports it, otherwise US English.
    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let synth = AVSpeechSynthesizer()
    private var lastVoiceAt = Date()
    private var silenceTimer: Timer?
    private var tapInstalled = false

    override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: Lifecycle

    @MainActor
    func begin() async {
        // Each failure gets its own message, so the fix is obvious.
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard micOK else {
            return fail("Microphone access is off. Turn it on in Settings › Privacy & Security › Microphone › Rounds.")
        }
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else {
            return fail("Speech recognition is off. Turn it on in Settings › Privacy & Security › Speech Recognition › Rounds.")
        }
        guard let recognizer, recognizer.isAvailable else {
            return fail("Speech recognition isn't available right now. Check your internet connection, or turn on Dictation in Settings › General › Keyboard.")
        }
        startListening()
    }

    @MainActor
    private func fail(_ message: String) {
        withAnimation(Springs.slide) { phase = .unavailable(message) }
    }

    func end() {
        withAnimation(Springs.slide) { phase = .idle }   // set first so delegate callbacks don't restart listening
        stopAudio()
        synth.stopSpeaking(at: .immediate)
        level = 0
        transcript = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Tap the orb: end your turn now, or cut the patient off and take the floor.
    func interrupt() {
        switch phase {
        case .listening: finishTurn()
        case .patientSpeaking: synth.stopSpeaking(at: .immediate)   // delegate hands the turn back
        default: break
        }
    }

    // MARK: Your turn

    private func startListening() {
        stopAudio()
        transcript = ""
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try s.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            // Prefer on-device, but never require it: the offline model is often not downloaded,
            // and requiring it makes recognition fail silently.
            req.requiresOnDeviceRecognition = false
            request = req

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                req.append(buffer)
                let sample = VoiceController.normalizedLevel(buffer)
                DispatchQueue.main.async { self?.ingest(sample) }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()

            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    guard self.phase == .listening else { return }
                    if let result {
                        let text = result.bestTranscription.formattedString
                        if text != self.transcript { self.transcript = text; self.lastVoiceAt = .now }
                    }
                    if let error = error as NSError? {
                        // 1110 = no speech heard before the recognizer gave up: just listen again.
                        if error.code == 1110 || error.code == 216 { self.startListening(); return }
                        if !self.transcript.isEmpty { self.finishTurn(); return }   // keep what we heard
                        self.stopAudio()
                        withAnimation(Springs.slide) {
                            self.phase = .unavailable("Couldn't understand that (\(error.localizedDescription)). Tap ✕ and try again, or type your question.")
                        }
                    }
                }
            }

            lastVoiceAt = .now
            withAnimation(Springs.slide) { phase = .listening }
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.checkSilence()
            }
        } catch {
            stopAudio()
            withAnimation(Springs.slide) {
                phase = .unavailable("The microphone couldn't start (\(error.localizedDescription)). Close other apps using audio and try again.")
            }
        }
    }

    private func ingest(_ sample: CGFloat) {
        guard phase == .listening else { return }
        level = level * (1 - VOICE.smoothing) + sample * VOICE.smoothing
    }

    private func checkSilence() {
        // With auto-send off in Settings, only a tap on the orb ends the turn.
        guard Preferences.autoSend, phase == .listening, !transcript.isEmpty,
              Date().timeIntervalSince(lastVoiceAt) > VOICE.silenceToSend else { return }
        finishTurn()
    }

    private func finishTurn() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopAudio()
        level = 0
        guard !text.isEmpty else { startListening(); return }
        withAnimation(Springs.slide) { phase = .thinking }
        onUtterance?(text)
    }

    private func stopAudio() {
        silenceTimer?.invalidate(); silenceTimer = nil
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
    }

    private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-7))
        return CGFloat(min(max((db - VOICE.levelFloorDb) / VOICE.levelRangeDb, 0), 1))
    }

    // MARK: Patient's turn

    func speak(_ text: String) {
        guard isActive else { return }
        stopAudio()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = VOICE.slowestRate + (VOICE.fastestRate - VOICE.slowestRate) * Float(Preferences.voiceSpeed)
        u.pitchMultiplier = VOICE.speechPitch
        withAnimation(Springs.slide) { phase = .patientSpeaking }
        synth.speak(u)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        // Each word is a small pulse; longer words push a little harder.
        let pulse = min(1, 0.35 + CGFloat(range.length) * 0.07)
        DispatchQueue.main.async { if self.phase == .patientSpeaking { self.level = pulse } }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { handBackTurn() }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { handBackTurn() }

    private func handBackTurn() {
        DispatchQueue.main.async {
            guard self.phase == .patientSpeaking else { return }
            self.level = 0
            self.startListening()
        }
    }

    #if DEBUG
    func debugPin(_ phase: Phase, level: CGFloat, transcript: String = "") {
        self.phase = phase; self.level = level; self.transcript = transcript
    }
    #endif
}
