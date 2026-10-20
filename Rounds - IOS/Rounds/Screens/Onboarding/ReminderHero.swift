import SwiftUI

/// "When should we remind you?": a lock-screen style notification, then the three times as
/// bubbles; one tap picks. The page's button asks iOS for permission and schedules it.
struct ReminderHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PracticeReminder.storageKey) private var stored = ""

    private var reminder: PracticeReminder? { PracticeReminder(stored: stored) }

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(314, 150).heroPop(shown, delay: 0.3)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(10, 372).heroPop(shown, delay: 0.34)
        }
        .overlay {
            VStack(spacing: 26) {
                banner.heroPop(shown, delay: 0)
                VStack(spacing: 12) {
                    ForEach(Array(PracticeReminder.allCases.enumerated()), id: \.element) { i, r in
                        ChoiceBubble(label: "\(r.period) · \(r.label)", on: reminder == r) {
                            withAnimation(reduceMotion ? nil : Springs.pop) { stored = r.rawValue }
                        }
                        .heroPop(shown, delay: 0.1 + Double(i) * 0.06)
                    }
                }
            }
        }
    }

    /// What the reminder will look like on the lock screen.
    private var banner: some View {
        let r = reminder ?? .evening
        return HStack(spacing: 12) {
            AppIcon(.brandMark, size: 22)
                .foregroundStyle(Theme.accentInk)
                .frame(width: 40, height: 40)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("ROUNDS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(r.label).font(.system(size: 11)).foregroundStyle(Theme.muted)
                        .contentTransition(.numericText())
                }
                Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text(r.body).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.text.opacity(0.12), radius: 20, y: 12)
        .accessibilityElement(children: .combine)
    }
}
