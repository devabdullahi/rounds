import AVFoundation
import Speech

/// Hears the student: the mic level and their words as Apple's speech recognition hears them, the
/// same way voice mode does in a case. Onboarding's voice tour uses it so it only moves on when the
/// student has really spoken. Nothing is recorded or kept, and nothing goes to an AI provider.
/// Call it from the main thread; its callbacks arrive there too.
final class SpeechTurnListener {
    /// Why listening can't start, said so the student knows what to change.
    enum Problem: Equatable {
        case micOff, speechOff, unavailable, couldNotStart

        var message: String {
            switch self {
            case .micOff: "Microphone access is off. Turn it on in Settings › Privacy & Security › Microphone › Rounds."
            case .speechOff: "Speech recognition is off. Turn it on in Settings › Privacy & Security › Speech Recognition › Rounds."
            case .unavailable: "Speech recognition isn't available right now. Check your connection."
            case .couldNotStart: "The microphone couldn't start. Close other apps using audio and try again."
            }
        }
    }

    /// 0…1, a few times a second while listening.
    var onLevel: (CGFloat) -> Void = { _ in }
    /// Everything heard since the last `start()`, each time it grows.
    var onHeard: (String) -> Void = { _ in }

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var running = false

    /// Asks for the microphone, then speech recognition; nil when both are allowed.
    func requestAccess() async -> Problem? {
        guard await AVAudioApplication.requestRecordPermission() else { return .micOff }
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else { return .speechOff }
        guard let recognizer, recognizer.isAvailable else { return .unavailable }
        return nil
    }

    /// Starts (or restarts) listening with an empty transcript.
    func start() -> Problem? {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                req.append(buffer)
                let level = micLevel(buffer)
                DispatchQueue.main.async { self?.onLevel(level) }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            running = true

            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self, self.running else { return }
                    if let text = result?.bestTranscription.formattedString, !text.isEmpty { self.onHeard(text) }
                    // The recognizer gives up after a stretch of quiet: listen again after a beat.
                    if error != nil {
                        self.stop()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in _ = self?.start() }
                    }
                }
            }
            return nil
        } catch {
            stop()
            return .couldNotStart
        }
    }

    func stop() {
        running = false
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
    }

    /// Stops and lets other apps' audio come back.
    func end() {
        stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
