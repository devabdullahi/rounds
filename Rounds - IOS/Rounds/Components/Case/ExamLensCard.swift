import SwiftUI

/// Debrief card for the student's exam: a title that names it and a few short points.
struct ExamLensCard: View {
    let lens: ExamLens
    /// False inside a debrief section row, which already shows the title and the surface.
    var framed = true

    var body: some View {
        if framed {
            content.card()
        } else {
            content.padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if framed { header }
            points
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
            HStack(spacing: 10) {
                AppIcon(.target, size: 20).foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(lens.title)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }

    private var points: some View {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lens.points.enumerated()), id: \.offset) { i, point in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                        Text(point)
                            .font(.system(size: 15))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
    }
}
