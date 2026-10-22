import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Reminders
 *
 *    0ms   lock screen settles; clock shows the picked time
 *  350ms   the reminder slides down onto the lock screen, y -24 → 0
 *  pick    clock and the reminder's time change to the new pick
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let notification = 0.35
}

/// "Get a nudge when patients are waiting?": the reminder as it will look on the lock screen, at
/// the time picked below. The page's button asks iOS for permission and schedules it.
struct ReminderPage: View {
    var shown = true
    @AppStorage(PracticeReminder.storageKey) private var stored = ""

    private var reminder: PracticeReminder? { PracticeReminder(stored: stored) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            lockScreen
                .padding(.top, 8)
            Text("Get a nudge when patients are waiting?")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ForEach(PracticeReminder.allCases) { r in choice(r) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    /// The lock screen at the picked time, with the reminder on it.
    private var lockScreen: some View {
        let r = reminder ?? .evening
        let clock = r.label.split(separator: " ").first.map(String.init) ?? r.label
        return VStack(spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.9)
            Text(clock)
                .font(.system(size: 76, weight: .light))
                .tracking(-2)
                .contentTransition(.numericText())
                .animation(.snappy, value: clock)
            notification(r)
                .padding(.top, 14)
                .rise(shown, at: TIMING.notification, offset: -24)
        }
        .foregroundStyle(Theme.accentInk)
        .padding(.top, 22)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.welcomeGreen, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: at \(r.label), Rounds says: \(r.title). \(r.body)")
    }

    private func notification(_ r: PracticeReminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppIcon(.brandMark, size: 20)
                .foregroundStyle(Theme.accentInk)
                .frame(width: 38, height: 38)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("Rounds").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("now").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Text(r.title).font(.system(size: 15, weight: .semibold))
                Text(r.body).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(12)
        .background(Theme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func choice(_ r: PracticeReminder) -> some View {
        let on = reminder == r
        return Button { stored = r.rawValue } label: {
            VStack(spacing: 2) {
                Text(r.period).font(.system(size: 15, weight: .semibold))
                Text(r.label).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(on ? Theme.accentSoft : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(on ? Theme.accent : Theme.border, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}
