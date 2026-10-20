import SwiftUI

/// What the AI consent asks the student to agree to: one short line per point, then a link to the
/// privacy policy. Shared by the onboarding page and the full-screen consent for returning accounts,
/// so both show the same words.
struct AIConsentPoints: View {
    let points: [String]
    let privacyPolicy: URL?

    /// One icon per point, in `AIConsent.points` order; a point past the end gets a plain check.
    private static let glyphs: [IconGlyph] = [.patientChart, .messageSquare, .lock, .info]

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
            if let privacyPolicy {
                Link(destination: privacyPolicy) {
                    HStack(spacing: 6) {
                        Text("Read the privacy policy")
                        AppIcon(.externalLink, size: 16)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
                }
            }
        }
    }
}
