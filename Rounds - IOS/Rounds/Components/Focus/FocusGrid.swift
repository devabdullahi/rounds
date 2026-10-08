import SwiftUI

/// Rotation or system tiles plus a "mix it up" row. Used by onboarding step 2.
/// Tiles toggle, so a student can pick several; "mix it up" clears them.
struct FocusGrid: View {
    let byRotation: Bool
    /// Conditions per topic, keyed by `StudyFocus.stored`; empty hides the counts.
    var counts: [String: Int] = [:]
    @Binding var selection: FocusSelection
    @Binding var mixChosen: Bool

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                if byRotation {
                    ForEach(Clerkship.allCases) { c in
                        tile(c.label, c.examples, .rotation(c))
                    }
                } else {
                    ForEach(OrganSystem.allCases) { s in
                        tile(s.label, s.examples, .system(s))
                    }
                }
            }
            MixRow(byRotation: byRotation, on: mixChosen && selection.isMix) {
                withAnimation(Springs.pop) { selection = FocusSelection(); mixChosen = true }
            }
        }
    }

    private func tile(_ label: String, _ detail: String, _ value: StudyFocus) -> some View {
        let on = selection.contains(value)
        let count = conditionCount(value, in: counts)
        return Button {
            withAnimation(Springs.pop) { selection.toggle(value); mixChosen = false }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text(label)
                        .font(.system(size: byRotation ? 16 : 15, weight: .semibold))   // system names run longer
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if on { FocusCheck(size: 20) }
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let count {
                    Text(count.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(count.empty ? Theme.faint : Theme.accentText)
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            // One fixed height per grid, sized for a two-line name, so every row lines up.
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: byRotation ? 122 : 92, alignment: .topLeading)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityValue(count?.text ?? "")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
