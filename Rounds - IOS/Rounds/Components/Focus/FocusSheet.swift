import SwiftUI

/// Home chip and Settings row open this: pick any rotations and systems, or a mix.
/// Rows use the onboarding selection look and keep the example complaints.
struct FocusSheet: View {
    /// Conditions per topic, keyed by `StudyFocus.stored`; empty hides the counts.
    var counts: [String: Int] = [:]
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""

    @State private var bySystem = false

    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Study focus").font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
            }
            Text(focus.isMix ? "Pick one or more. Matching patients come first." : "\(focus.items.count) picked · matching patients come first.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)

            Segmented(options: [(false, "Rotation"), (true, "System")], selection: $bySystem)
                .padding(.top, 14)

            ScrollView {
                VStack(spacing: 8) {
                    if bySystem {
                        ForEach(OrganSystem.allCases) { s in row(s.label, s.examples, .system(s)) }
                    } else {
                        ForEach(Clerkship.allCases) { c in row(c.label, c.examples, .rotation(c)) }
                    }
                    MixRow(byRotation: !bySystem, on: focus.isMix) {
                        withAnimation(Springs.pop) { focusStored = FocusSelection().stored }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .onAppear { bySystem = focus.leadsWithSystem }
    }

    private func row(_ label: String, _ detail: String, _ value: StudyFocus) -> some View {
        let on = focus.contains(value)
        let count = conditionCount(value, in: counts)
        return Button {
            var next = focus
            next.toggle(value)
            withAnimation(Springs.pop) { focusStored = next.stored }
        } label: {
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
