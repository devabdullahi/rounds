import SwiftUI

/// The layout every onboarding question shares: an icon badge and the question at the top,
/// left-aligned, an optional short note under it, then the answers. `shown` plays the entrance
/// (see QuestionEntrance.swift).
struct OnboardingQuestion<Answers: View>: View {
    let title: String
    var glyph: IconGlyph?
    var note: String?
    var shown = true
    @ViewBuilder let answers: () -> Answers

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let glyph {
                    AppIcon(glyph, size: 24)
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent.opacity(0.14), in: Circle())
                        .padding(.bottom, 16)
                        .accessibilityHidden(true)
                        .modifier(QuestionEntrance(order: 0, lift: 8, start: 0))
                }
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(QuestionEntrance(order: 0, lift: 8, start: 0))
                if let note {
                    Text(note)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                        .modifier(QuestionEntrance(order: 0, lift: 8, start: 0))
                }
                VStack(spacing: 10) { answers() }
                    .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .environment(\.questionShown, shown)
    }
}
