import AVFoundation
import Foundation
import WebRTC

/// A live voice call with OpenAI's Realtime API over WebRTC. Audio flows phone ↔ OpenAI on media
/// tracks (WebRTC plays the patient's voice itself); JSON events flow on the `oai-events` data
/// channel. The SDP offer goes through our server, which adds the patient's instructions and the
/// API key: neither ever reaches the phone.
///
/// The audio session is set through WebRTC's own wrapper in voice-chat mode, which turns on the
/// hardware echo canceller. Without it the patient hears their own voice through the speaker,
/// takes it for the student talking, and interrupts themselves.
@MainActor
final class RealtimeClient: NSObject, LiveVoiceTransport {
    /// One factory for the app; SSL is initialized with it, once.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory()
    }()

    private enum LEVELS {
        static let interval: Duration = .milliseconds(100)   // how often the orb's loudness updates
    }

    let events: AsyncStream<LiveVoiceEvent>
    /// Fed from WebRTC's threads as well as the main actor; a continuation is safe to share.
    private nonisolated let continuation: AsyncStream<LiveVoiceEvent>.Continuation
    private var peer: RTCPeerConnection?
    private var channel: RTCDataChannel?
    private var meter: Task<Void, Never>?

    override init() {
        (events, continuation) = AsyncStream.makeStream(of: LiveVoiceEvent.self)
        super.init()
    }

    func connect(exchange: @escaping @Sendable (String) async throws -> String) async throws {
        try Self.useVoiceChatAudio()
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw CaseServiceError(message: "Live voice couldn't start the audio connection.")
        }
        self.peer = peer

        // The mic track and the data channel go in before the offer, or they aren't in the SDP.
        let source = Self.factory.audioSource(with: constraints)
        peer.add(Self.factory.audioTrack(with: source, trackId: "mic"), streamIds: ["student"])
        let channel = peer.dataChannel(forLabel: "oai-events", configuration: RTCDataChannelConfiguration())
        channel?.delegate = self
        self.channel = channel

        let receiveAudio = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        let offer = try await peer.offer(for: receiveAudio)
        try await peer.setLocalDescription(offer)
        let answer = try await exchange(offer.sdp)
        try await peer.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: answer))
        startMeter()
    }

    func cutOffPatient() {
        // Stop generating, then drop whatever audio is still queued to play.
        send(["type": "response.cancel"])
        send(["type": "output_audio_buffer.clear"])
    }

    func disconnect() {
        meter?.cancel(); meter = nil
        channel?.close(); channel = nil
        peer?.close(); peer = nil
        let audio = RTCAudioSession.sharedInstance()
        audio.lockForConfiguration()
        try? audio.setActive(false)
        audio.unlockForConfiguration()
        continuation.finish()
    }

    // MARK: Plumbing

    /// Play and record in voice-chat mode, on the loudspeaker (or Bluetooth), via WebRTC's wrapper so
    /// its audio unit and our settings don't fight.
    private static func useVoiceChatAudio() throws {
        let audio = RTCAudioSession.sharedInstance()
        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
        config.categoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        audio.lockForConfiguration()
        defer { audio.unlockForConfiguration() }
        try audio.setConfiguration(config, active: true)
    }

    /// Sends a client event; dropped if the channel isn't open yet (nothing to cut off then).
    private func send(_ event: [String: String]) {
        guard let channel, channel.readyState == .open, let data = try? JSONSerialization.data(withJSONObject: event) else { return }
        channel.sendData(RTCDataBuffer(data: data, isBinary: false))
    }

    /// Reads the mic's and the patient's loudness from WebRTC's stats, for the orb.
    private func startMeter() {
        meter = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: LEVELS.interval)
                guard let self, let peer = self.peer else { return }
                let report = await peer.statistics()
                var mic = 0.0, patient = 0.0
                for stat in report.statistics.values {
                    let level = (stat.values["audioLevel"] as? NSNumber)?.doubleValue ?? 0
                    if stat.type == "media-source" { mic = max(mic, level) }
                    if stat.type == "inbound-rtp" { patient = max(patient, level) }
                }
                self.continuation.yield(.levels(mic: mic, patient: patient))
            }
        }
    }
}

// MARK: - WebRTC callbacks (on WebRTC's own threads: they only pass events on)

extension RealtimeClient: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        // A failed or closed connection ends the call; the student can start a new one. No auto-retry loop.
        if newState == .failed || newState == .closed || newState == .disconnected { continuation.yield(.disconnected) }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

extension RealtimeClient: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {}

    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard !buffer.isBinary, let event = LiveVoiceEventParser.parse(buffer.data) else { return }
        continuation.yield(event)
    }
}
