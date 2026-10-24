import SwiftUI

/// "What do you want to practice?": eight tiles, a mix or the core rotations, any number picked,
/// and "Other" for the remaining specialties in a sheet. Nothing shows as picked until the student
/// taps, and Continue waits for that. Body systems stay in the Focus sheet.
struct PracticePage: View {
    var shown = true
    /// Called on every pick, so the page's Continue can open.
    var onPicked: () -> Void = {}
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var touched = false
    @State private var showsOther = false

    private static let rotations: [(Clerkship, IconGlyph)] = [
        (.internalMedicine, .stethoscope), (.surgery, .firstAid), (.pediatrics, .user), (.obgyn, .heartbeat),
        (.psychiatry, .messageSquare), (.neurology, .lightning), (.emergency, .siren),
    ]

    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    /// Specialties without a tile of their own, listed behind "Other".
    private static let others = Clerkship.allCases.filter { c in !rotations.contains { $0.0 == c } }

    /// The "Other" specialties picked so far, in list order.
    private var pickedOthers: [Clerkship] {
        touched ? Self.others.filter { focus.contains(.rotation($0)) } : []
    }

    var body: some View {
        OnboardingQuestion(title: "What do you want to practice?", shown: shown) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("Mix of everything", .shuffle, on: touched && focus.isMix, order: 0) { pick(FocusSelection()) }
                ForEach(Array(Self.rotations.enumerated()), id: \.offset) { i, item in
                    tile(item.0.label, item.1, on: touched && focus.contains(.rotation(item.0)), order: i + 1) {
                        toggle(.rotation(item.0))
                    }
                }
            }
            otherTile
                .padding(.top, 10)
            Text("Pick any. Change it anytime.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }

    /// Full width under the grid, so the eight tiles stay an even block. Names what was picked.
    private var otherTile: some View {
        let on = !pickedOthers.isEmpty
        return Button { showsOther = true } label: {
            HStack(spacing: 12) {
                AppIcon(.more, size: 24).foregroundStyle(on ? Theme.accentText : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Other").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(on ? pickedOthers.map(\.label).joined(separator: ", ") : "Family medicine, dermatology, cardiology…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                AppIcon(.chevronRight, size: 16).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(14)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityLabel("Other specialties")
        .accessibilityValue(on ? pickedOthers.map(\.label).joined(separator: ", ") : "")
        .accessibilityAddTraits(on ? .isSelected : [])
        .modifier(QuestionEntrance(order: 4))
        .sheet(isPresented: $showsOther) { otherSheet }
    }

    private var otherSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Other specialties").font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Done") { showsOther = false }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            ScrollView {
                FocusTopicList(focus: focus, bySystem: false, showsSelection: touched, rotations: Self.others, showsMix: false,
                               onToggle: toggle, onMix: {})
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
    }

    private func toggle(_ value: StudyFocus) {
        // The first tap starts a fresh pick, so an old selection from a past run can't linger.
        var next = touched ? focus : FocusSelection()
        next.toggle(value)
        pick(next)
    }

    private func tile(_ title: String, _ glyph: IconGlyph, on: Bool, order: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                AppIcon(glyph, size: 24).foregroundStyle(on ? Theme.accentText : Theme.muted)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(14)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
        .modifier(QuestionEntrance(order: order / 2))
    }

    private func pick(_ selection: FocusSelection) {
        withAnimation(Springs.pop) {
            touched = true
            focusStored = selection.stored
        }
        onPicked()
    }
}
