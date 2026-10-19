import SwiftUI
import AVFoundation
import Speech
import Observation

/// Turn-taking voice conversation with the patient.
/// You speak (mic level + live transcript) → silence ends your turn → patient answers aloud → your turn again.
///
/// With `transcriber` and `spokenReply` set (the case session's server calls), each turn is also
/// recorded and transcribed by the server, which hears clinical words better than on-device
/// recognition, and the patient answers in a natural OpenAI voice. Apple's live transcript still
/// shows while you talk and decides when you've stopped; if a server call fails, Apple's text and
/// Apple's voice take over, so voice mode never stops working.
@Observable
final class VoiceController: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    enum Phase: Equatable {
        case idle
        case listening         // your turn
        case thinking          // question sent, waiting on the patient
        case patientSpeaking   // patient answering aloud
        case unavailable(String)
    }

    private enum VOICE {
        static let silenceToSend: TimeInterval = 0.9  // quiet this long after speaking → send (was 1.4: felt slow)
        static let levelFloorDb: Float = -50          // dB mapped to level 0
        static let levelRangeDb: Float = 40           // dB span mapped to 0…1
        static let smoothing: CGFloat = 0.35          // new-sample weight
        static let slowestRate: Float = 0.35         // Settings speed 0
        static let fastestRate: Float = 0.65         // Settings speed 1; 0.5 in between is the natural rate
        static let slowestPlayback: Float = 0.85     // server voice at Settings speed 0
        static let fastestPlayback: Float = 1.25     // server voice at Settings speed 1
        static let recordBitRate = 32_000            // AAC, mono: ~4 KB a second, well under the upload cap
    }

    private(set) var phase: Phase = .idle
    private(set) var level: CGFloat = 0          // 0…1, mic level when listening, word pulses when patient speaks
    private(set) var transcript = ""
    var onUtterance: ((String) -> Void)?
    /// The server's transcription of a recorded turn; nil keeps Apple's live transcript.
    @ObservationIgnored var transcriber: ((Data) async throws -> String)?
    /// The patient's latest reply as server audio; nil speaks with the installed iOS voice.
    @ObservationIgnored var spokenReply: (() async throws -> Data)?
    /// Asks the spoken question and gets the answer's voice in one round trip (nil: the question
    /// failed). When set, it replaces `onUtterance` plus a separate request for the voice.
    @ObservationIgnored var askAloud: ((String) async -> (reply: String, audio: AsyncThrowingStream<Data, Error>)?)?
    /// The same reply streamed as PCM, played as it arrives. Tried first; `spokenReply` is the fallback.
    @ObservationIgnored var streamedReply: (() async throws -> AsyncThrowingStream<Data, Error>)?
    @ObservationIgnored private var streamer: StreamingVoicePlayer?
    @ObservationIgnored private var streaming: Task<Void, Never>?

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
    /// The patient's voice and pitch, chosen once per case (see PatientVoice).
    private var patientVoice: AVSpeechSynthesisVoice?
    private var patientPitch: Float = 1
    /// This turn's recording, written alongside recognition and sent to `transcriber`.
    @ObservationIgnored private var recording: AVAudioFile?
    private let recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice-turn.m4a")
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var meterTimer: Timer?

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
        stopPlayer()
        level = 0
        transcript = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Tap the orb: end your turn now, or cut the patient off and take the floor.
    func interrupt() {
        switch phase {
        case .listening: finishTurn()
        case .patientSpeaking:
            if player != nil || streaming != nil { stopPlayer(); handBackTurn() } else { synth.stopSpeaking(at: .immediate) }   // the synth's delegate hands the turn back
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
            recording = transcriber == nil ? nil : makeRecording(format: format)
            let file = recording
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                req.append(buffer)
                try? file?.write(from: buffer)
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
        let recorded = recording != nil
        stopAudio()   // closes the recording file
        level = 0
        guard !text.isEmpty else { startListening(); return }
        withAnimation(Springs.slide) { phase = .thinking }
        guard recorded, let transcriber, let audio = try? Data(contentsOf: recordingURL) else { send(text); return }
        Task { @MainActor in
            // The server's text when it hears something; Apple's when the call fails or comes back empty.
            let heard = (try? await transcriber(audio))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard phase == .thinking else { return }   // voice mode ended while transcribing
            send(heard.isEmpty ? text : heard)
        }
    }

    /// Hands the finished question on: asked aloud (answer and voice in one go) when that's set up,
    /// otherwise to `onUtterance`, whose answer comes back through `speak`.
    private func send(_ question: String) {
        guard let askAloud else { onUtterance?(question); return }
        Task { @MainActor in
            guard let answer = await askAloud(question) else { end(); return }   // the error shows in the chat
            guard phase == .thinking else { return }
            speakStreamed(answer.reply) { answer.audio }
        }
    }

    /// An AAC file for this turn in the mic's own sample rate, or nil if one can't be made (the turn
    /// then goes through with Apple's transcript).
    private func makeRecording(format: AVAudioFormat) -> AVAudioFile? {
        try? FileManager.default.removeItem(at: recordingURL)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: VOICE.recordBitRate,
        ]
        return try? AVAudioFile(forWriting: recordingURL, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    }

    private func stopAudio() {
        silenceTimer?.invalidate(); silenceTimer = nil
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
        recording = nil   // releasing the file finishes it
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

    /// Picks this patient's voice: the best installed English voice of their sex, the same one every time.
    func usePatient(sex: String, age: Int, seed: String) {
        patientVoice = PatientVoice.pick(from: PatientVoice.installed(), sex: sex, seed: seed).flatMap(AVSpeechSynthesisVoice.init(identifier:))
        patientPitch = PatientVoice.pitch(age: age)
    }

    func speak(_ text: String) {
        guard isActive else { return }
        stopAudio()
        if let streamedReply { speakStreamed(text, from: streamedReply); return }
        speakFromFile(text)
    }

    /// Plays the reply while it streams in; falls back to the whole-file voice if nothing arrives.
    private func speakStreamed(_ text: String, from source: @escaping () async throws -> AsyncThrowingStream<Data, Error>) {
        streaming = Task { @MainActor in
            let player = streamer ?? StreamingVoicePlayer()
            streamer = player
            usePlaybackSession()
            let rate = VOICE.slowestPlayback + (VOICE.fastestPlayback - VOICE.slowestPlayback) * Float(Preferences.voiceSpeed)
            do {
                try await player.play(try await source(), rate: rate) { [weak self] in
                    guard let self, self.isActive else { return }
                    withAnimation(Springs.slide) { self.phase = .patientSpeaking }
                    self.meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated {
                            guard let self, self.phase == .patientSpeaking, let streamer = self.streamer else { return }
                            self.level = self.level * (1 - VOICE.smoothing) + streamer.currentLevel * VOICE.smoothing
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                meterTimer?.invalidate(); meterTimer = nil
                if phase == .patientSpeaking { handBackTurn() }
            } catch {
                guard isActive, !Task.isCancelled else { return }
                speakFromFile(text)
            }
        }
    }

    private func speakFromFile(_ text: String) {
        guard let spokenReply else { speakOnDevice(text); return }
        // Stays "thinking" while the server voices the reply, then plays it.
        Task { @MainActor in
            guard let audio = try? await spokenReply(), isActive else {
                if isActive { speakOnDevice(text) }
                return
            }
            play(audio, fallback: text)
        }
    }

    /// Plays the server's audio, or falls back to the on-device voice if it won't play.
    private func play(_ audio: Data, fallback text: String) {
        usePlaybackSession()
        guard let p = try? AVAudioPlayer(data: audio, fileTypeHint: "public.aac-audio") else { speakOnDevice(text); return }
        p.delegate = self
        p.enableRate = true
        p.rate = VOICE.slowestPlayback + (VOICE.fastestPlayback - VOICE.slowestPlayback) * Float(Preferences.voiceSpeed)
        p.isMeteringEnabled = true
        player = p
        withAnimation(Springs.slide) { phase = .patientSpeaking }
        p.play()
        // The orb pulses with the voice's loudness, like it does with the mic.
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player, self.phase == .patientSpeaking else { return }
            player.updateMeters()
            let db = player.averagePower(forChannel: 0)
            let sample = CGFloat(min(max((db - VOICE.levelFloorDb) / VOICE.levelRangeDb, 0), 1))
            self.level = self.level * (1 - VOICE.smoothing) + sample * VOICE.smoothing
        }
    }

    private func stopPlayer() {
        meterTimer?.invalidate(); meterTimer = nil
        player?.stop(); player = nil
        streaming?.cancel(); streaming = nil
        streamer?.stop()
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopPlayer()
            self.handBackTurn()
        }
    }

    /// While listening the session is in call mode (playAndRecord), which on Bluetooth headphones
    /// plays through the low-quality hands-free channel and makes any voice sound robotic. The
    /// patient speaks through plain playback instead; startListening switches back for your turn.
    private func usePlaybackSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? s.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// The installed iOS voice: used when no server voice is set, or when it fails.
    private func speakOnDevice(_ text: String) {
        usePlaybackSession()
        let u = AVSpeechUtterance(string: text)
        u.voice = patientVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        u.rate = VOICE.slowestRate + (VOICE.fastestRate - VOICE.slowestRate) * Float(Preferences.voiceSpeed)
        u.pitchMultiplier = patientPitch
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
