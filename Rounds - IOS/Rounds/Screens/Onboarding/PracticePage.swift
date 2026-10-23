import SwiftUI

/// "What do you want to practice?": eight tiles, a mix or the core rotations, any number picked.
/// Nothing shows as picked until the student taps, and Continue waits for that. Body systems and
/// the other specialties stay in the Focus sheet.
struct PracticePage: View {
    var shown = true
    /// Called on every pick, so the page's Continue can open.
    var onPicked: () -> Void = {}
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var touched = false

    private static let rotations: [(Clerkship, IconGlyph)] = [
        (.internalMedicine, .stethoscope), (.surgery, .firstAid), (.pediatrics, .user), (.obgyn, .heartbeat),
        (.psychiatry, .messageSquare), (.neurology, .lightning), (.emergency, .siren),
    ]

    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    var body: some View {
        OnboardingQuestion(title: "What do you want to practice?", shown: shown) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("Mix of everything", .shuffle, on: touched && focus.isMix, order: 0) { pick(FocusSelection()) }
                ForEach(Array(Self.rotations.enumerated()), id: \.offset) { i, item in
                    tile(item.0.label, item.1, on: touched && focus.contains(.rotation(item.0)), order: i + 1) {
                        // The first tap starts a fresh pick, so an old selection from a past run can't linger.
                        var next = touched ? focus : FocusSelection()
                        next.toggle(.rotation(item.0))
                        pick(next)
                    }
                }
            }
            Text("Pick any. Change it anytime.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
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
