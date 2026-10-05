import SwiftUI

/// Sits where the patient deck would be when nobody is waiting: admits a newly written patient.
/// Generation takes a while, so the card says so instead of just spinning.
struct AdmitCard: View {
    let admitting: Bool
    /// The ward is still loading, so "nobody waiting" isn't known yet.
    let loading: Bool
    let onAdmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(admitting ? "Admitting" : "Ward is quiet", color: Theme.accent)
            Spacer(minLength: 16)
            Text(admitting ? "Your patient is on the way." : "No patients waiting.")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            Text(admitting
                 ? "A new case is being written for your focus. This takes about 15 seconds."
                 : "Admit a new patient. Each one is written fresh for your focus, so no two are the same.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 24)
            Button(action: onAdmit) {
                HStack(spacing: 10) {
                    if admitting || loading { ProgressView().tint(.white) }
                    Text(admitting ? "Preparing patient…" : loading ? "Loading ward…" : "Admit a new patient")
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 54))
            .disabled(admitting || loading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: STACK.cardHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
    }
}
