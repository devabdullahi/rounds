import SwiftUI

/// The bedside monitor pinned above the interview chat: the triage HR, BP and SpO₂, and a live
/// ECG at the patient's heart rate, so the patient stays in view while the history is taken.
struct PatientMonitor: View {
    let vitals: [Vital]

    /// The monitor vitals (HR, BP, SpO₂); temperature and the rest stay on the door note.
    private var shown: [Vital] { vitals.filter { $0.tone != .plain } }

    /// Beats per minute for the trace, from the HR vital ("104" or "104 bpm").
    private var heartRate: Double {
        vitals.first { $0.id == "hr" }.flatMap { Double($0.value.prefix { $0.isNumber }) } ?? 80
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(shown) { v in
                    VStack(alignment: v.id == shown.last?.id ? .trailing : .leading, spacing: 1) {
                        Text(v.label).font(.system(size: 11, weight: .semibold))
                        Text(v.value).font(.mono(17))
                    }
                    .foregroundStyle(color(v.tone))
                    .frame(maxWidth: .infinity, alignment: alignment(of: v))
                }
            }
            ECGMonitor(bpm: heartRate, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monitor: " + shown.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }

    /// First column hugs the left, last the right, any middle one centres, like the website's monitor.
    private func alignment(of v: Vital) -> Alignment {
        if v.id == shown.first?.id { return .leading }
        if v.id == shown.last?.id { return .trailing }
        return .center
    }

    private func color(_ tone: Vital.Tone) -> Color {
        switch tone {
        case .accent: Theme.accent
        case .warn: Theme.warn
        case .info: Theme.info
        case .plain: Theme.text
        }
    }
}

#Preview {
    PatientMonitor(vitals: [
        Vital(id: "hr", label: "HR", value: "88"),
        Vital(id: "bp", label: "BP", value: "113/73"),
        Vital(id: "spo2", label: "SpO₂", value: "97"),
    ])
    .padding()
    .background(Theme.bg)
}
