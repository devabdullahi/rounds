import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · How voice works (driven by the student's voice)
 *
 *  you talk          orb follows your mic level; your words appear under it
 *  you pause 0.9s    your words rise in as a bubble; orb settles ("Dana is thinking…")
 *  +900ms            orb compresses and turns blue; Dana's answer slides in
 *  you talk over her she's cut off; orb springs back to green (your turn again)
 *  +2400ms           (last answer) the tour is done
 *
 * The orb is the app's own VoiceOrb: your real mic level on your turn, a voice-like level on hers.
 * Reduce Motion: no slides, a steady level on her turn.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let think: Duration = .milliseconds(900)
    static let lastAnswer: Duration = .milliseconds(2400)
}

/// "How voice works": the student talks to Dana out loud, exactly as in a case. A pause sends
/// what they said; talking over her first answer cuts her off. A card says what to say on each
/// turn. Nothing moves on until they've really spoken; with the mic or speech recognition off,
/// they're told how to turn it on, or can type instead.
struct VoiceTourPage: View {
    var shown = true
    /// Called once the tour is done, so the page's Next can open.
    var onFinished: () -> Void = {}
    /// The student can't or won't use the mic: voice off, and on past the tour.
    var onTypeInstead: () -> Void = {}

    @State private var tour = VoiceTour()
    @State private var turns = 0
    @State private var listener = SpeechTurnListener()
    @State private var problem: SpeechTurnListener.Problem?
    /// The mic level and the words heard on the current turn.
    @State private var micLevel: CGFloat = 0
    @State private var heardNow = ""
    @State private var lastHeardAt = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var orbPhase: VoiceController.Phase {
        switch tour.phase {
        case .listening, .done: .listening
        case .thinking: .thinking
        case .patient: .patientSpeaking
        }
    }

    private var coach: String {
        switch tour.phase {
        case .listening: tour.asked == 0 ? "Just talk. Ask Dana when her sore throat started." : "You have the floor. Ask your next question."
        case .thinking: "Sent. Dana heard you."
        case .patient: tour.asked == 1 ? "She's still talking. Talk over her to cut in." : "She answers out loud."
        case .done: "That's voice. Ask anything, any time."
        }
    }

    private var status: String {
        switch tour.phase {
        case .listening, .done: "Your turn. Speak to Dana."
        case .thinking: "Dana is thinking…"
        case .patient: "Dana is answering"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(coach)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: coach)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            conversation
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 20)

            if let line = tour.toSay {
                sayCard(line)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            panel
        }
        .animation(reduceMotion ? nil : Springs.slide, value: tour)
        .task(id: tour.phase) { await advance() }
        .task(id: shown) { if shown { await listen() } else { listener.end() } }
        .onDisappear { listener.end() }
        .onChange(of: tour.phase) { _, phase in
            if phase == .done { listener.end(); onFinished() }
        }
    }

    private var conversation: some View {
        VStack(spacing: 8) {
            ForEach(Array(tour.shown.enumerated()), id: \.offset) { _, line in
                Text(line.question)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.bubbleMe, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 4, topTrailingRadius: 18))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 48)
                    .transition(reduceMotion ? .opacity : .offset(x: 20).combined(with: .opacity))
                if let reply = line.reply {
                    Text(reply)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 48)
                        .transition(reduceMotion ? .opacity : .offset(x: -20).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func sayCard(_ line: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tour.phase == .patient ? "Talk over her and say" : "Say this out loud")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accentText)
            Text("“\(line)”")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
        .accessibilityElement(children: .combine)
    }

    /// The voice panel as a case shows it: status, the orb, and the hint under it.
    private var panel: some View {
        VStack(spacing: 10) {
            Text(status)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tour.phase == .patient ? Theme.info : Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
            TimelineView(.animation(paused: reduceMotion || tour.phase != .patient)) { ctx in
                VoiceOrb(phase: orbPhase, level: level(at: ctx.date))
            }
            .frame(width: 180, height: 180)
            .accessibilityHidden(true)
            .sensoryFeedback(.impact(weight: .light), trigger: turns)
            Group {
                if let problem {
                    VStack(spacing: 8) {
                        Text(problem.message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.warnText)
                        Button("Type instead", action: onTypeInstead)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accentText)
                            .frame(minHeight: 44)
                    }
                } else if tour.phase == .listening, !heardNow.isEmpty {
                    Text(heardNow).foregroundStyle(Theme.text).lineLimit(2)
                } else {
                    Text(tour.phase == .patient ? "Talk to interrupt" : "Just talk; Dana answers when you pause")
                        .foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13))
            .frame(minHeight: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    /// The student's real mic level on their turn; on Dana's, a voice-like level (two slow waves).
    private func level(at date: Date) -> CGFloat {
        switch tour.phase {
        case .listening: return micLevel
        case .patient:
            if reduceMotion { return 0.25 }
            let t = date.timeIntervalSinceReferenceDate
            return CGFloat(0.28 + 0.22 * sin(t * 5.1) + 0.14 * sin(t * 8.3))
        default: return 0
        }
    }

    /// Asks for the mic and speech recognition, then listens for the rest of the tour.
    private func listen() async {
        guard tour.phase != .done else { return }
        if let denied = await listener.requestAccess() { problem = denied; return }
        listener.onLevel = { micLevel = micLevel * 0.65 + $0 * 0.35 }
        listener.onHeard = { heard($0) }
        problem = listener.start()
        // A pause after enough words ends the turn, as in a case.
        while !Task.isCancelled, problem == nil {
            try? await Task.sleep(for: .milliseconds(200))
            if tour.phase == .listening, VoiceTour.turnIsOver(heard: heardNow, quietFor: Date.now.timeIntervalSince(lastHeardAt)) {
                if tour.send(heardNow) { turns += 1 }
                restart()
            }
        }
    }

    /// Words came in: the current turn grows, or (over Dana's first answer) the student cuts in.
    private func heard(_ text: String) {
        switch tour.phase {
        case .listening:
            heardNow = text
            lastHeardAt = .now
        case .patient:
            if tour.interrupt() { turns += 1; restart() }
        default:
            break
        }
    }

    /// A fresh transcript for the next turn.
    private func restart() {
        heardNow = ""
        micLevel = 0
        problem = listener.start()
    }

    /// The patient's side of the script: think, then answer; the last answer ends the tour.
    private func advance() async {
        switch tour.phase {
        case .thinking:
            try? await Task.sleep(for: TIMING.think)
            guard !Task.isCancelled else { return }
            tour.patientAnswers()
        case .patient where tour.asked >= VoiceTour.lines.count:
            try? await Task.sleep(for: TIMING.lastAnswer)
            guard !Task.isCancelled else { return }
            tour.patientFinished()
        default:
            break
        }
    }
}
