import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Welcome to the team (after buying)
 *
 *    0ms   ID badge drops in on its lanyard, y -340 → 0, swinging -9° → 0 (spring)
 *  800ms   headline rises, y 12 → 0
 *  950ms   plan line and button rise
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let headline = 0.8
    static let rest = 0.95
}

private enum LANYARD {
    static let dropFrom: CGFloat = -340
    static let swing: Double = -9
    static let drop = Animation.spring(response: 0.8, dampingFraction: 0.55)
}

/// Shown once, right after a plan is bought: the student's Rounds ID badge on a lanyard, then
/// "Start my first shift" into the app.
struct WelcomeAboardView: View {
    let name: String?
    let year: SchoolYear?
    let goal: StudyGoal?
    let plan: ActivePlan?
    let onStart: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var planLine: String {
        guard let plan else { return "Your plan is active." }
        if plan.isTrial {
            return "Free until \(plan.periodEnd.formatted(.dateTime.month(.abbreviated).day())). We'll remind you the day before."
        }
        return "Rounds \(plan.period.name) is active."
    }

    var body: some View {
        VStack(spacing: 0) {
            lanyard
                .offset(y: shown || reduceMotion ? 0 : LANYARD.dropFrom)
                .rotationEffect(.degrees(shown || reduceMotion ? 0 : LANYARD.swing), anchor: .top)
                .animation(reduceMotion ? nil : LANYARD.drop, value: shown)
            Spacer(minLength: 16)
            VStack(spacing: 14) {
                Text(name.map { "Welcome to the team, \($0)" } ?? "Welcome to the team")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .rise(shown, at: TIMING.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(planLine)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .rise(shown, at: TIMING.rest)
                Button("Start my first shift", action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                    .rise(shown, at: TIMING.rest)
            }
            .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.heroMint
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 500).offset(y: -120)
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 340).offset(y: -120)
            }
            .ignoresSafeArea()
        }
        .onAppear { shown = true }
    }

    private var lanyard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 46) {
                strap.rotationEffect(.degrees(8))
                strap.rotationEffect(.degrees(-8))
            }
            .frame(height: 110)
            RoundedRectangle(cornerRadius: 6).fill(Theme.track).frame(width: 46, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.faint, lineWidth: 2))
            badge.padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Rounds badge", name, year?.label, goal?.label].compactMap { $0 }.joined(separator: ", "))
    }

    private var strap: some View {
        Rectangle().fill(Theme.accentFill).frame(width: 18)
    }

    private var badge: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    AppIcon(.brandMark, size: 22)
                    Text("ROUNDS").font(.system(size: 16, weight: .heavy)).tracking(0.5)
                }
                Spacer()
                Text("STUDENT").font(.system(size: 11, weight: .heavy)).tracking(1.2).opacity(0.8)
            }
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(Theme.accentFill)

            VStack(spacing: 10) {
                Text(initial)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 84, height: 84)
                    .background(Theme.accentSoft, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 4))
                VStack(spacing: 2) {
                    Text(name ?? "Student doctor").font(.system(size: 24, weight: .bold)).tracking(-0.4)
                    Text([name == nil ? nil : "Student doctor", year?.label].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 8) {
                    field("PLAN", plan?.period.name ?? "Rounds")
                    field("FOCUS", goal?.label ?? "Every rotation")
                }
                .padding(.top, 4)
            }
            .foregroundStyle(Theme.text)
            .padding(18)
        }
        .frame(width: 248)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.text.opacity(0.18), radius: 24, y: 16)
    }

    private var initial: String {
        name?.first.map { String($0).uppercased() } ?? "R"
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
