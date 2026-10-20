import SwiftUI

/// "See where you're getting better": an example progress card (labelled as an example): cases,
/// right diagnoses, and a bar per topic with the weakest one called out.
struct ProgressHero: View {
    let shown: Bool

    private static let topics: [(String, Double, Bool)] = [
        ("Cardiology", 0.9, false), ("Neurology", 0.7, false), ("Pediatrics", 0.45, true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("EXAMPLE WEEK").font(.system(size: 13, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.muted)
                Spacer()
                Text("5-day streak").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentText)
            }
            HStack(spacing: 28) {
                stat("12", "Cases")
                stat("83%", "Right diagnosis")
            }
            VStack(spacing: 10) {
                ForEach(Self.topics, id: \.0) { name, share, weak in
                    HStack(spacing: 10) {
                        Text(name).font(.system(size: 14)).frame(width: 100, alignment: .leading)
                        GeometryReader { geo in
                            Capsule().fill(Theme.track)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(weak ? Theme.wrong : Theme.accent).frame(width: geo.size.width * share)
                                }
                        }
                        .frame(height: 8)
                    }
                }
            }
            Text("Weakest topic: Pediatrics. More of those next.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.text)
        .padding(20)
        .frame(maxWidth: 350)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.text.opacity(0.08), radius: 20, y: 12)
        .heroPop(shown, delay: 0)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example progress: 12 cases, 83 percent right diagnosis, weakest topic pediatrics.")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 28, weight: .bold))
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }
}
