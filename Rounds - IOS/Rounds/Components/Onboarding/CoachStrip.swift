import SwiftUI

/// The dark strip over onboarding's sample case: which step of the case this is, and what to do
/// next. The line changes as the student acts, so it reads like someone beside them.
struct CoachStrip: View {
    let step: Int
    let of: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("STEP \(step) OF \(of)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.accentInk.opacity(0.75))
                .fixedSize()
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accentInk)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.welcomeGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step) of \(of). \(text)")
    }
}
