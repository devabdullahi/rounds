import SwiftUI

/// The topic rows of the Focus sheet and onboarding's "What do you want to practice?": every
/// specialty or every body system, then "mix it up". Takes the selection and reports taps; the
/// caller saves them.
struct FocusTopicList: View {
    let focus: FocusSelection
    let bySystem: Bool
    /// Conditions per topic, keyed by `StudyFocus.stored`; empty hides the counts.
    var counts: [String: Int] = [:]
    /// Off until the student has tapped something, so a fresh onboarding shows nothing picked
    /// (an empty selection would otherwise read as "mix").
    var showsSelection = true
    let onToggle: (StudyFocus) -> Void
    let onMix: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if bySystem {
                ForEach(OrganSystem.allCases) { s in row(s.label, s.examples, .system(s)) }
            } else {
                ForEach(Clerkship.allCases) { c in row(c.label, c.examples, .rotation(c)) }
            }
            MixRow(byRotation: !bySystem, on: showsSelection && focus.isMix, action: onMix)
        }
    }

    private func row(_ label: String, _ detail: String, _ value: StudyFocus) -> some View {
        let on = showsSelection && focus.contains(value)
        let count = conditionCount(value, in: counts)
        return Button { onToggle(value) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 16, weight: .semibold))
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                if let count {
                    Text(count.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(count.empty ? Theme.faint : Theme.accentText)
                }
                if on { FocusCheck(size: 20) }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityValue(count?.text ?? "")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
