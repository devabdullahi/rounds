import SwiftUI

/// Debrief card that teaches the case's condition: the key points first, then typical symptoms
/// and risk factors as chips, so it reads in a few seconds right after the score.
struct ConditionAboutCard: View {
    let diagnosis: String
    let about: ConditionAbout
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
        VStack(alignment: .leading, spacing: 14) {
            if framed { header }
            summary
            chips("Typical symptoms", about.symptoms)
            chips("Risk factors", about.riskFactors)
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
            HStack(spacing: 10) {
                AppIcon(.bookOpen, size: 20).foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text("About \(diagnosis)")
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var summary: some View {
            if !about.summaryPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(about.summaryPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(.top, 7)
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

    @ViewBuilder
    private func chips(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(title)
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { Pill(text: $0, fg: Theme.dim, bg: Theme.track) }
                }
            }
            // One spoken list instead of a swipe per chip.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(items.joined(separator: ", "))")
        }
    }
}
