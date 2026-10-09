import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Segmented control
 *
 * One persistent thumb, never re-inserted, so it always slides.
 *
 *   press   thumb shrinks 1.0 → 0.95 under the finger
 *   drag    thumb follows the finger segment to segment (scrub),
 *           selection haptic on every segment crossed
 *   tap     thumb springs to the tapped segment (interruptible:
 *           a second tap mid-flight redirects from where it is)
 *   release thumb springs back to 1.0; value commits
 *   labels  crossfade weight + color in place; widths never change
 * ───────────────────────────────────────────────────────── */

private enum SEG {
    static let height: CGFloat = 44
    static let inset: CGFloat = 3
    static let radius: CGFloat = 12
    static let thumbRadius: CGFloat = 9
    static let pressedScale: CGFloat = 0.95
    static let slide = Animation.spring(response: 0.32, dampingFraction: 0.82)   // thumb travel
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)    // squeeze in/out
    static let label = Animation.easeOut(duration: 0.18)                         // text crossfade
    static let thumb = Theme.thumb                                               // lifts off track and card
}

struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    @Environment(\.isEnabled) private var isEnabled
    @State private var pressing = false
    @State private var scrubIndex: Int?

    private var committedIndex: Int { options.firstIndex { $0.0 == selection } ?? 0 }
    private var shownIndex: Int { scrubIndex ?? committedIndex }

    var body: some View {
        GeometryReader { geo in
            let segW = (geo.size.width - 2 * SEG.inset) / CGFloat(max(options.count, 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: SEG.thumbRadius, style: .continuous)
                    .fill(SEG.thumb)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .frame(width: segW, height: geo.size.height - 2 * SEG.inset)
                    .scaleEffect(pressing ? SEG.pressedScale : 1)
                    .offset(x: SEG.inset + CGFloat(shownIndex) * segW)
                    .animation(SEG.slide, value: shownIndex)
                    .animation(SEG.press, value: pressing)

                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        let on = i == shownIndex
                        // Both weights are always laid out; only opacity changes, so nothing shifts.
                        ZStack {
                            Text(option.1).font(.system(size: 15, weight: .regular)).foregroundStyle(Theme.dim).opacity(on ? 0 : 1)
                            Text(option.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).opacity(on ? 1 : 0)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: segW, height: geo.size.height)
                        .animation(SEG.label, value: on)
                    }
                }
                .offset(x: SEG.inset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !pressing { pressing = true }
                        let i = min(max(Int((v.location.x - SEG.inset) / segW), 0), options.count - 1)
                        if scrubIndex != i { scrubIndex = i }
                    }
                    .onEnded { _ in
                        pressing = false
                        if let i = scrubIndex, options[i].0 != selection { selection = options[i].0 }
                        scrubIndex = nil
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: SEG.height)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: SEG.radius, style: .continuous))
        .haptic(.selection, trigger: shownIndex)
        .accessibilityRepresentation {
            Picker("", selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
