import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Try an interview (per tapped question)
 *
 *    0ms   question bubble slides in from the right, chip leaves the list
 *    0ms   typing dots appear under it
 *  900ms   dots give way to the patient's reply, sliding in from the left
 * 1100ms   "Revealed: <topic>" chip pops
 *
 * Reduce Motion: no slides, the reply shows at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let reply: Duration = .milliseconds(900)
    static let reveal: Duration = .milliseconds(200)
}

/// "Ask your first patient": show, don't tell. A scripted patient and three question chips; each
/// tap plays the exchange the way a real case does (typing, reply, revealed topic). Optional:
/// Continue works with nothing asked.
struct TryInterviewPage: View {
    var shown = true

    private let interview = SampleInterview.burning
    @State private var asked: [String] = []
    /// The question whose reply is still "typing"; its reply and chip wait.
    @State private var typing: String?
    @State private var revealed: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(title: "Ask your first patient", shown: shown) {
            patientCard
                .padding(.bottom, 6)
                .modifier(QuestionEntrance(order: 0))

            ForEach(interview.asked(asked)) { exchange in
                conversation(exchange)
            }

            let left = interview.exchanges.filter { !asked.contains($0.id) }
            if !left.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(left.enumerated()), id: \.element.id) { i, exchange in
                        chip(exchange).modifier(QuestionEntrance(order: i + 1))
                    }
                }
                .padding(.top, asked.isEmpty ? 0 : 8)
                .disabled(typing != nil)
            }
        }
    }

    private var patientCard: some View {
        HStack(spacing: 12) {
            PatientAvatar(initials: interview.initials, size: 40, tint: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(interview.patient).font(.system(size: 15, weight: .semibold))
                Text(interview.complaint).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.text)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.text.opacity(0.08)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func conversation(_ exchange: SampleInterview.Exchange) -> some View {
        VStack(spacing: 8) {
            Text(exchange.question)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.bubbleMe, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 4, topTrailingRadius: 18))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 48)
                .transition(reduceMotion ? .opacity : .offset(x: 20).combined(with: .opacity))
            if typing == exchange.id {
                TypingDots()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else {
                Text(exchange.reply)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 48)
                    .transition(reduceMotion ? .opacity : .offset(x: -20).combined(with: .opacity))
                if revealed.contains(exchange.id) {
                    Pill(text: "Revealed: \(exchange.reveals)", glyph: .check)
                        .frame(maxWidth: .infinity)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func chip(_ exchange: SampleInterview.Exchange) -> some View {
        Button { ask(exchange) } label: {
            Text(exchange.question)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.text.opacity(0.10)))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityHint("Asks the patient")
    }

    /// Plays one exchange: the question, a beat of typing, the reply, then its revealed topic.
    private func ask(_ exchange: SampleInterview.Exchange) {
        guard typing == nil else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) {
            asked.append(exchange.id)
            typing = reduceMotion ? nil : exchange.id
        }
        Task {
            if !reduceMotion { try? await Task.sleep(for: TIMING.reply) }
            withAnimation(reduceMotion ? nil : Springs.slide) { typing = nil }
            if !reduceMotion { try? await Task.sleep(for: TIMING.reveal) }
            withAnimation(reduceMotion ? nil : Springs.pop) { _ = revealed.insert(exchange.id) }
        }
    }
}
