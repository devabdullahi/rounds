import SwiftUI

/// Debrief card for "what else it could have been": each alternative, whether the student listed
/// it, why it fit, and how to tell it apart. Long lists start collapsed (must-not-miss rows always show).
struct DifferentialReviewCard: View {
    let items: [DifferentialReview]
    /// Conditions the student listed that don't usually belong here, already phrased.
    let extrasNote: String?
    /// Rows shown before "Show all".
    var collapsedLimit = 3
    /// False inside a debrief section row, which already shows the title and the surface.
    var framed = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAll = false

    var body: some View {
        let visible = showAll ? items : DifferentialReview.collapsed(items, limit: collapsedLimit)
        let hidden = items.count - DifferentialReview.collapsed(items, limit: collapsedLimit).count

        let list = VStack(alignment: .leading, spacing: 0) {
            if framed {
                Text("What else it could have been")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }

            ForEach(Array(visible.enumerated()), id: \.element.id) { i, item in
                if i > 0 { Hairline() }
                appearing(DifferentialReviewRow(item: item), index: i)
            }

            if hidden > 0 {
                Hairline()
                Button { withAnimation(reduceMotion ? nil : DISCLOSURE.open) { showAll.toggle() } } label: {
                    HStack {
                        Text(showAll ? "Show fewer" : "Show all \(items.count)")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accentText)
                        Spacer()
                        DisclosureChevron(open: showAll)
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }

            if let extrasNote {
                Hairline()
                Text(extrasNote)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .foregroundStyle(Theme.text)

        if framed {
            list.listSurface().clipped()
        } else {
            list.clipped()
        }
    }

    /// Rows revealed by "Show all" drop in like every other disclosure, except under Reduce Motion.
    @ViewBuilder
    private func appearing(_ row: DifferentialReviewRow, index: Int) -> some View {
        if reduceMotion { row } else { row.disclosureItem(index) }
    }
}
