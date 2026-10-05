import SwiftUI

/// How many conditions a focus can draw new patients from, as a short label: "12 conditions",
/// "Coming soon". nil while the counts haven't loaded (e.g. signed out), so nothing shows.
private func conditionCount(_ focus: StudyFocus, in counts: [String: Int]) -> (text: String, empty: Bool)? {
    guard !counts.isEmpty else { return nil }
    let n = counts[focus.stored] ?? 0
    return n == 0 ? ("Coming soon", true) : ("\(n) \(n == 1 ? "condition" : "conditions")", false)
}

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

/// "Mix it up": the escape hatch, shared by onboarding and the sheet so it reads the same.
struct MixRow: View {
    let byRotation: Bool
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AppIcon(.shuffle, size: 20).foregroundStyle(Theme.accentText)
                Text(byRotation ? "Between rotations · mix it up" : "Not sure · mix it up")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if on { FocusCheck(size: 20) }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct FocusCheck: View {
    let size: CGFloat
    var body: some View {
        AppIcon(.circleCheck, size: size)
            .foregroundStyle(Theme.accent)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}

/// The onboarding option look: surface card, accent ring and wash when picked.
struct SelectableSurface: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content
            .background(on ? Theme.accent.opacity(0.10) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Theme.text.opacity(0.10), lineWidth: on ? 1.5 : 1)
            )
            .contentShape(Rectangle())
    }
}

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
