import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · How your free trial works
 *
 *    0ms   three day cards deal in from the right, 90ms apart
 *  250ms   headline rises, y 12 → 0
 *  500ms   timeline bar fills down (1200ms); steps pop in at 550 / 950 / 1350ms
 * 1700ms   "No payment due today" settles
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let cardStagger = 0.09
    static let headline = 0.25
    static let bar = 0.5
    static let steps = [0.55, 0.95, 1.35]
    static let badge = 1.7
}

/// The page before the plans: what the free trial does, day by day, so the price comes after the
/// promise of a reminder and a free cancel. "See the plans" opens the paywall.
struct TrialIntroView: View {
    let name: String?
    let onContinue: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return [0, 2, 3].compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        VStack(spacing: 0) {
            cards
                .padding(.top, 60)   // clear of the account button over the top-left corner
            Text(name.map { "\($0), try all of Rounds free for 3 days" } ?? "Try all of Rounds free for 3 days")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .rise(shown, at: TIMING.headline)
                .accessibilityAddTraits(.isHeader)
            timeline
                .padding(.top, 26)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                AppIcon(.check, size: 16)
                Text("No payment due today").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.accentText)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.accentSoft, in: Capsule())
            .rise(shown, at: TIMING.badge)
            Button("See the plans", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { shown = true }
    }

    private var cards: some View {
        HStack(spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let today = i == 0
                VStack(spacing: 2) {
                    Text(today ? "TODAY" : day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.system(size: 12, weight: .heavy)).tracking(1)
                        .foregroundStyle(today ? Theme.accentInk.opacity(0.8) : Theme.muted)
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 34, weight: .bold)).tracking(-1)
                    Text(["Free", "Reminder", "Plan starts"][i])
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(today ? Theme.accentInk : i == 1 ? Theme.accentText : Theme.muted)
                }
                .foregroundStyle(today ? Theme.accentInk : Theme.text)
                .frame(width: 92, height: 104)
                .background(today ? Theme.accentFill : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(today ? .clear : Theme.border))
                .shadow(color: today ? Theme.accent.opacity(0.35) : .clear, radius: 14, y: 8)
                .rotationEffect(.degrees([-4, 0, 4][i]))
                .offset(x: shown || reduceMotion ? 0 : 60)
                .opacity(shown ? 1 : 0)
                .animation(reduceMotion ? nil : Springs.slide.delay(Double(i) * TIMING.cardStagger), value: shown)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today free, a reminder in 2 days, and the plan starts in 3 days")
    }

    private var timeline: some View {
        let steps: [(IconGlyph, String, String)] = [
            (.lock, "Today: everything unlocks", "Unlimited patients, voice visits, full debriefs."),
            (.bell, "\(days[1].formatted(.dateTime.weekday(.wide))): we remind you", "A nudge the day before your trial ends."),
            (.star, "\(days[2].formatted(.dateTime.weekday(.wide))): your plan starts", "Cancel before then in Settings and pay nothing."),
        ]
        return VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 16) {
                    AppIcon(step.0, size: 20)
                        .foregroundStyle(Theme.accentInk)
                        .frame(width: 44, height: 44)
                        .background(i == 2 ? Theme.good : Theme.accentFill, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.1).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                        Text(step.2).font(.system(size: 15)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
                .rise(shown, at: TIMING.steps[i])
            }
        }
        .background(alignment: .leading) {
            // The bar behind the icons, filling down as the steps arrive.
            Capsule().fill(Theme.accentSoft).frame(width: 8)
                .overlay(alignment: .top) {
                    Capsule().fill(Theme.accent).frame(width: 8)
                        .scaleEffect(y: shown ? 1 : 0, anchor: .top)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).delay(TIMING.bar), value: shown)
                }
                .padding(.vertical, 22)
                .padding(.leading, 18)
        }
    }
}
