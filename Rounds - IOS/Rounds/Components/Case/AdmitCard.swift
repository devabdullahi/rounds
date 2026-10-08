import SwiftUI

/// Sits where the patient deck would be when nobody is waiting: admits a newly written patient.
/// While one is being written, organs draw themselves in turn (`AnatomyLoader`), since generation
/// takes 10–30 s and a bare spinner reads as stuck. The first case in a topic takes minutes, since
/// the condition itself is written first; the copy says so.
struct AdmitCard: View {

    let admitting: Bool
    var preparing = false
    /// The ward is still loading, so "nobody waiting" isn't known yet.
    let loading: Bool
    let onAdmit: () -> Void

    /// When the current preparing wait began, for the elapsed clock.
    @State private var preparingSince: Date?

    private var eyebrow: String {
        admitting ? (preparing ? "New condition" : "Admitting") : "Bed open"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(eyebrow, color: Theme.accent)
            if admitting {
                Spacer(minLength: 8)
                AnatomyLoader()
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 8)
                VStack(spacing: 6) {
                    Text(preparing ? "Preparing a new condition…" : "Finding your patient…")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)
                    Text(preparing ? "First case in this topic, about 3 minutes" : "A new case is being written. About 15 seconds.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                    // A long wait with a moving clock reads as progress, not as stuck.
                    if preparing, let since = preparingSince {
                        Text(since, style: .timer)
                            .font(.mono(15, weight: .medium))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                Spacer(minLength: 16)
                Text("No patients waiting.")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every patient is written fresh for your focus, so no two are alike.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 16)
                // An empty bed: the monitor sweeps, but there's no rhythm on it. The readout makes
                // the line read as a monitor rather than a progress bar.
                VStack(alignment: .leading, spacing: 6) {
                    Text("HR  ---")
                        .font(.mono(13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                    ECGMonitor(color: Theme.faint, flatline: true)
                }
                Spacer(minLength: 16)
                Button(action: onAdmit) {
                    HStack(spacing: 10) {
                        if loading { ProgressView().tint(.white) }
                        Text(loading ? "Loading ward…" : "Admit a new patient")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .disabled(loading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: STACK.cardHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 24, y: 10)
        .animation(.easeOut(duration: 0.3), value: admitting)
        .onChange(of: preparing, initial: true) { _, now in preparingSince = now ? Date() : nil }
        .accessibilityElement(children: .contain)
    }
}
