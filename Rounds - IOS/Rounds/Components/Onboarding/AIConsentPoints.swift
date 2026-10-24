import SwiftUI

/// What the consent asks the student to agree to: one short line per point, then a note that
/// "I agree" accepts the Terms of Use and Privacy Policy, with a link to each.
struct AIConsentPoints: View {
    let points: [String]
    let note: String
    let terms: URL?
    let privacyPolicy: URL?

    /// One icon per point, in `AIConsent.points` order; a point past the end gets a plain check.
    private static let glyphs: [IconGlyph] = [.patientChart, .messageSquare, .lock, .info, .stethoscope]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 14) {
                    AppIcon(Self.glyphs.indices.contains(index) ? Self.glyphs[index] : .check, size: 20)
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 36, height: 36)
                        .background(Theme.accentSoft, in: Circle())
                        .accessibilityHidden(true)
                    Text(point)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 7)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 20) {
                    if let terms { documentLink("Terms of Use", to: terms) }
                    if let privacyPolicy { documentLink("Privacy Policy", to: privacyPolicy) }
                }
            }
        }
    }

    private func documentLink(_ title: String, to url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Text(title)
                AppIcon(.externalLink, size: 16)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
        }
    }
}
