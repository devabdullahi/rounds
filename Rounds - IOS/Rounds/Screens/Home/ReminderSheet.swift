import SwiftUI

/// The daily reminder, offered once over Home after onboarding: the lock-screen preview and three
/// times (ReminderPage), then turn it on (iOS asks for permission) or not now.
struct ReminderSheet: View {
    let onDone: () -> Void
    @Environment(AppState.self) private var app
    @AppStorage(PracticeReminder.storageKey) private var stored = ""

    var body: some View {
        VStack(spacing: 4) {
            ReminderPage(shown: true)
                .padding(.top, 24)
            OnboardingNextButton(title: "Turn On Reminders", enabled: PracticeReminder(stored: stored) != nil) {
                guard let reminder = PracticeReminder(stored: stored) else { return }
                Task {
                    // iOS asks for permission here; the sheet closes whatever the answer.
                    _ = await app.setPracticeReminder(reminder)
                    onDone()
                }
            }
            Button("Not now", action: onDone)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
        }
        .padding(.bottom, 8)
        .background(Theme.surface.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear { if stored.isEmpty { stored = PracticeReminder.evening.rawValue } }
    }
}
