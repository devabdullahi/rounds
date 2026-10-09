import SwiftUI

/// One alternative diagnosis in the debrief: name, a red "Must not miss" pill when dangerous,
/// whether it was on the student's list, why it fit, and the findings that tell it apart.
struct DifferentialReviewRow: View {
    let item: DifferentialReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 8) {
                if item.mustNotMiss {
                    Pill(text: "Must not miss", fg: Theme.warnText, bg: Theme.warnSoft, glyph: .triangleAlert)
                }
                listStatus
            }

            if !item.why.isEmpty {
                Text(item.why)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !item.tellApart.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to tell apart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                    ForEach(item.tellApart, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Theme.faint).frame(width: 4, height: 4).padding(.top, 8)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// Green check when the student listed it; a quiet note otherwise, since missing a
    /// non-dangerous alternative isn't a mistake worth shouting about.
    private var listStatus: some View {
        HStack(spacing: 4) {
            AppIcon(item.inYours ? .check : .circle, size: 14)
            Text(item.inYours ? "On your list" : "Not on your list")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(item.inYours ? Theme.good : Theme.muted)
        .padding(.vertical, 6)
    }
}
