import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · How voice works (driven by taps)
 *
 *  tap (your turn)   your line rises in; orb settles and breathes ("Dana is thinking…")
 *  +900ms            orb compresses and turns blue; Dana's answer slides in
 *  tap (her turn)    she's cut off; orb springs back to green (your turn again)
 *  +2400ms           (last answer) the tour is done
 *
 * The orb is the app's own VoiceOrb, fed a simulated voice level while someone talks.
 * Reduce Motion: no slides, a steady level instead of a moving one.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let think: Duration = .milliseconds(900)
    static let lastAnswer: Duration = .milliseconds(2400)
}

/// "How voice works": the student taps the orb to send each line, and to cut the patient off,
/// exactly as in a case. A card says what to say on each turn. Nothing moves on until they tap.
struct VoiceTourPage: View {
    var shown = true

    @State private var tour = VoiceTour()
    @State private var taps = 0
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
        case .listening: tour.asked == 0 ? "Just talk. Ask Dana when her pain started." : "You have the floor. Ask your next question."
        case .thinking: "Sent. Dana heard you."
        case .patient: tour.asked == 1 ? "She's still talking. Tap the orb to cut in." : "She answers out loud."
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
            Text(tour.phase == .patient ? "Tap the orb, then say" : "Say this, then tap the orb")
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
            Button {
                if tour.tap() { taps += 1 }
            } label: {
                TimelineView(.animation(paused: reduceMotion || !talking)) { ctx in
                    VoiceOrb(phase: orbPhase, level: level(at: ctx.date))
                }
                .frame(width: 180, height: 180)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(tour.phase == .thinking || tour.phase == .done || (tour.phase == .patient && tour.asked > 1))
            .accessibilityLabel(tour.phase == .patient ? "Interrupt Dana" : "Send what you said")
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            Text(tour.phase == .patient ? "Talk or tap the orb to interrupt" : "Just talk; Dana answers when you pause")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    /// Someone is talking, so the orb should move.
    private var talking: Bool { tour.phase == .listening || tour.phase == .patient }

    /// A voice-like level: two slow waves, so the orb swells and settles like speech.
    private func level(at date: Date) -> CGFloat {
        guard talking else { return 0 }
        if reduceMotion { return 0.25 }
        let t = date.timeIntervalSinceReferenceDate
        return CGFloat(0.28 + 0.22 * sin(t * 5.1) + 0.14 * sin(t * 8.3))
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
