import SwiftUI

/// "How are your interviews?": three stacked level cards, each with a signal-bar glyph; one tap picks.
struct InterviewLevelHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(InterviewLevel.storageKey) private var stored = ""

    /// Each card's sideways nudge, so the stack reads as floating rather than a form.
    private static let nudge: [InterviewLevel: CGFloat] = [.justStarting: -15, .gettingThere: 15, .confident: -5]

    private var level: InterviewLevel? { InterviewLevel(stored: stored) }

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(4, 30)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(318, 350)
        }
        .overlay {
            VStack(spacing: 18) {
                ForEach(Array(InterviewLevel.allCases.enumerated()), id: \.element) { i, l in
                    card(l)
                        .offset(x: Self.nudge[l] ?? 0)
                        .heroPop(shown, delay: Double(i) * 0.06)
                }
            }
        }
    }

    private func card(_ l: InterviewLevel) -> some View {
        let on = level == l
        return Button {
            withAnimation(reduceMotion ? nil : Springs.pop) { stored = l.rawValue }
        } label: {
            HStack(spacing: 16) {
                SignalBars(lit: l.bars, on: on)
                Text(l.label).font(.system(size: 20, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(on ? Theme.accentInk : Theme.text)
            .padding(.horizontal, 22)
            .frame(width: 300, height: 84)
            .background(on ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: (on ? Theme.accent : Theme.text).opacity(on ? 0.32 : 0.10), radius: on ? 16 : 11, y: on ? 14 : 8)
            .scaleEffect(on && !reduceMotion ? 1.04 : 1)
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Three rising bars, the first `lit` filled: how far along this level is.
private struct SignalBars: View {
    let lit: Int
    let on: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i <= lit ? (on ? Theme.accentInk : Theme.accent)
                                   : (on ? Theme.accentInk.opacity(0.35) : Theme.text.opacity(0.16)))
                    .frame(width: 7, height: CGFloat(4 + i * 8))
            }
        }
        .frame(height: 28, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
