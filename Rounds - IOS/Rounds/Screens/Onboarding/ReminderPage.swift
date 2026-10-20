import SwiftUI

/// "When should we remind you to practice?": three times and a preview of the notification. The
/// page's button asks iOS for permission and schedules it.
struct ReminderPage: View {
    var shown = true
    @AppStorage(PracticeReminder.storageKey) private var stored = ""

    private var reminder: PracticeReminder? { PracticeReminder(stored: stored) }

    var body: some View {
        OnboardingQuestion(title: "When should we remind you to practice?", glyph: .bell, shown: shown) {
            ForEach(Array(PracticeReminder.allCases.enumerated()), id: \.element) { i, r in
                ChoiceRow(title: r.period, trailing: r.label, glyph: .clock, tint: ChoiceRow.tint(i + 3),
                          on: reminder == r, order: i) { stored = r.rawValue }
            }
            Text("PREVIEW")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .modifier(QuestionEntrance(order: 3))
            preview.modifier(QuestionEntrance(order: 4))
        }
    }

    /// What the reminder will look like on the lock screen.
    private var preview: some View {
        let r = reminder ?? .evening
        return HStack(spacing: 12) {
            AppIcon(.brandMark, size: 20)
                .foregroundStyle(Theme.accentInk)
                .frame(width: 38, height: 38)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("ROUNDS").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(r.label).font(.system(size: 12))
                }
                .foregroundStyle(Theme.muted)
                Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text(r.body).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.text.opacity(0.08)))
        .accessibilityElement(children: .combine)
    }
}
