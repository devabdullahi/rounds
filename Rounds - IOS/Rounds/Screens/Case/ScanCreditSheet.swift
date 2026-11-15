import SwiftUI

/// Where the teaching X-ray comes from: plain words, the source link and the citation the
/// dataset asks for. Opened from the credit line under the report.
struct ScanCreditSheet: View {
    let scan: ScanImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("About this image").font(.system(size: 20, weight: .bold))
                Spacer()
                IconButton(glyph: .x, label: "Close", size: 18, quiet: true) { dismiss() }
            }
            Text("A real, de-identified chest X-ray from a public teaching dataset (\(scan.credit)). It's a teaching example, not this patient's own scan.")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Source")
                Link(destination: scan.sourceURL) {
                    HStack(spacing: 6) {
                        Text(scan.sourceURL.host() ?? scan.sourceURL.absoluteString).lineLimit(1)
                        AppIcon(.externalLink, size: 14)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
                }
                Eyebrow("Citation")
                Text(scan.citation)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.dim)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(24)
        .foregroundStyle(Theme.text)
        .presentationDetents([.medium])
        .presentationBackground(Theme.surface)
    }
}
