import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Underline tabs
 *
 * The second level of tabs, lighter than Segmented above it.
 *   tap    underline springs to the tapped tab (one persistent bar,
 *          matched geometry, so it slides rather than re-appearing)
 *   label  weight and colour crossfade; widths never change
 * Reduce Motion: the underline moves without the spring.
 * ───────────────────────────────────────────────────────── */

private enum UNDERLINE {
    static let height: CGFloat = 44
    static let bar: CGFloat = 3
    static let slide = Animation.spring(response: 0.32, dampingFraction: 0.82)
}

/// Text tabs with a sliding underline, for choices inside a tab (Workup's Exam and Tests), so the
/// two levels of navigation don't look alike.
struct UnderlineTabs<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let (value, label) = option
                let selected = value == selection
                Button {
                    withAnimation(reduceMotion ? nil : UNDERLINE.slide) { selection = value }
                } label: {
                    VStack(spacing: 0) {
                        Text(label)
                            .font(.system(size: 16, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.text : Theme.muted)
                            .frame(maxHeight: .infinity)
                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: UNDERLINE.bar)
                            if selected {
                                Capsule().fill(Theme.accent).frame(height: UNDERLINE.bar)
                                    .matchedGeometryEffect(id: "bar", in: bar)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: UNDERLINE.height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
