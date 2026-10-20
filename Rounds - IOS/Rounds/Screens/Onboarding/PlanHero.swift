import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Your plan (on arrival)
 *
 *    0ms   summary card pops in, scale 0.85 → 1
 *  250ms+  each answer row pops in, 180ms apart (Name, Year, Goal, Focus)
 *  ~1.1s   "First patient waiting" pill pops below the card
 *
 * Reads the stored answers, so the student sees their choices built into one plan.
 * Reduce Motion: everything shown at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let firstRow = 0.25
    static let rowGap = 0.18
    static let afterRows = 0.15
}

/// "Your Rounds are ready": the onboarding answers read back as one plan, right before the account ask.
struct PlanHero: View {
    let shown: Bool
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(ProfileName.storageKey) private var nameStored = ""
    @AppStorage(CareSetting.storageKey) private var settingStored = ""

    private var plan: OnboardingPlan {
        OnboardingPlan(name: nameStored, year: SchoolYear(stored: yearStored), goal: StudyGoal(stored: goalStored),
                       focus: FocusSelection(stored: focusStored), setting: CareSetting(stored: settingStored))
    }

    var body: some View {
        let rows = plan.rows
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(318, 10)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(4, 372)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    HStack(spacing: 12) {
                        AppIcon(.check, size: 12)
                            .foregroundStyle(Theme.accentInk)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent, in: Circle())
                        Text(row.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 60, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)   // "Internal medicine +1 · Clinic" fits whole
                        Spacer(minLength: 0)
                    }
                    .frame(height: 52)
                    .heroPop(shown, delay: TIMING.firstRow + Double(i) * TIMING.rowGap)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(width: 350)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.text.opacity(0.10), radius: 24, y: 14)
            .at(0, 60)
            .heroPop(shown, delay: 0)

            HStack(spacing: 10) {
                Text("RM")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 36, height: 36)
                    .background(Theme.heroMint, in: Circle())
                Text("First patient waiting").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.accentInk)
            .padding(.leading, 8).padding(.trailing, 18)
            .frame(height: 52)
            .background(Theme.accent, in: Capsule())
            .shadow(color: Theme.accent.opacity(0.32), radius: 16, y: 14)
            .at(70, 60 + 12 + CGFloat(rows.count) * 53 + 26)
            .heroPop(shown, delay: TIMING.firstRow + Double(rows.count) * TIMING.rowGap + TIMING.afterRows)
        }
        // The canvas hides its art from VoiceOver; the plan itself is worth reading out.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.map { "\($0.title): \($0.value)" }.joined(separator: ", ") + ". First patient waiting.")
    }
}
