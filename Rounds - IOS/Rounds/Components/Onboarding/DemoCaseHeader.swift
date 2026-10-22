import SwiftUI

/// The top of a case as the app draws it (patient, demeanor, clock, History/Workup, Exam/Tests),
/// for onboarding's sample case. Shown, not used: the switches stay on Workup and the tab the page
/// is about, so the student learns the real screen without wandering off the step.
struct DemoCaseHeader: View {
    let patient: String
    let mood: String
    let clock: String
    /// True on the Tests tab, false on Exam.
    let onTests: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Color.clear.frame(width: 64, height: 1)
                Spacer()
                VStack(spacing: 0) {
                    Text(patient).font(.system(size: 17, weight: .semibold))
                    Text(mood).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                Text(clock)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .frame(width: 64, alignment: .trailing)
            }
            .foregroundStyle(Theme.text)
            Segmented(options: [(false, "History"), (true, "Workup")], selection: .constant(true))
                .allowsHitTesting(false)
            HStack(spacing: 0) {
                tab("Exam", on: !onTests)
                tab("Tests", on: onTests)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patient), \(onTests ? "Tests" : "Exam")")
    }

    private func tab(_ title: String, on: Bool) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.accentText : Theme.muted)
            Rectangle()
                .fill(on ? Theme.accent : Theme.text.opacity(0.10))
                .frame(height: on ? 3 : 1)
        }
        .frame(maxWidth: .infinity)
    }
}
