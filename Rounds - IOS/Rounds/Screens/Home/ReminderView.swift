import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Turn on notifications
 *
 *    0ms   bell pops in, scale 0.6 → 1 (spring)
 *  300ms   bell swings once, -14° → 12° → -6° → 0 (900ms)
 * Reduce Motion: bell still, at rest.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let swing = 0.3
}

/// The daily reminder, offered once as its own full screen after onboarding (and after the welcome
/// that follows a purchase). Kept simple: what it's for, Allow (iOS asks for permission next) or
/// Skip. The time is the evening one; students change it in Settings.
struct ReminderView: View {
    let onDone: () -> Void
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PracticeReminder.storageKey) private var stored = ""
    @State private var shown = false
    @State private var swung = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            AppIcon(.bell, size: 36)
                .foregroundStyle(Theme.accentText)
                .rotationEffect(.degrees(swung || reduceMotion ? 0 : -14), anchor: .top)
                .frame(width: 72, height: 72)
                .background(Theme.accentSoft, in: Circle())
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                .opacity(shown || reduceMotion ? 1 : 0)
                .accessibilityHidden(true)
            Text("Turn on notifications")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            Text("Know when a patient is waiting for you. One nudge a day, at most.")
                .font(.system(size: 17))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Button("Allow notifications") {
                Task {
                    // iOS asks for permission here; the screen closes whatever the answer.
                    if await app.setPracticeReminder(.evening) { stored = PracticeReminder.evening.rawValue }
                    onDone()
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 56))
            Button("Skip for now", action: onDone)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(Capsule().strokeBorder(Theme.text.opacity(0.14)))
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .task {
            guard !reduceMotion else { return }
            withAnimation(Springs.pop) { shown = true }
            try? await Task.sleep(for: .seconds(TIMING.swing))
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 6)) { swung = true }
        }
    }
}
