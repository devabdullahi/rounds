import SwiftUI

/// "Why did you download Rounds?": what the student hopes to get out of it, one tap picks.
struct DownloadReasonPage: View {
    var shown = true
    @AppStorage(DownloadReason.storageKey) private var stored = ""

    private static let glyphs: [DownloadReason: IconGlyph] = [
        .confidence: .messageSquare, .differentials: .target, .rotations: .hospital, .exams: .graduationCap,
    ]

    var body: some View {
        OnboardingQuestion(title: "Why did you download Rounds?", shown: shown) {
            ForEach(Array(DownloadReason.allCases.enumerated()), id: \.element) { i, reason in
                ChoiceRow(title: reason.label, glyph: Self.glyphs[reason], tint: ChoiceRow.tint(i),
                          on: DownloadReason(stored: stored) == reason, order: i) { stored = reason.rawValue }
            }
        }
    }
}
