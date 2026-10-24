import SwiftUI

/// Debrief card with what to do differently on the next patient: the attending's misses and any red
/// flags not screened, each as a short title and why it matters. Optionally ends with turning them
/// into flashcards.
struct FixNextTimeCard: View {
    struct Item: Identifiable {
        let title: String
        let detail: String
        /// One of the areas the student said they find hardest.
        var isFocus = false
        var id: String { title }
    }

    let items: [Item]
    /// Closes the case and makes cards from the misses; nil hides the button.
    var makeCards: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Fix next time")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(items.count == 1 ? "1 miss" : "\(items.count) misses")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(Theme.warn).frame(width: 8, height: 8).padding(.top, 7)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        if item.isFocus {
                            Text("Your focus")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.accentText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.accent.opacity(0.14), in: Capsule())
                                .padding(.bottom, 2)
                                .accessibilityLabel("One of the areas you said you find hardest")
                        }
                        Text(item.title).font(.system(size: 16, weight: .semibold))
                        Text(item.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let makeCards {
                Button(action: makeCards) {
                    HStack(spacing: 8) {
                        AppIcon(.cards, size: 18)
                        Text(items.count == 1 ? "Turn this miss into a card" : "Turn misses into cards")
                    }
                }
                .buttonStyle(SoftButtonStyle(height: 46, fontSize: 15))
                .accessibilityHint("Closes the case and makes flashcards from your mistakes")
            }
        }
        .foregroundStyle(Theme.text)
        .card(radius: 20, padding: 18)
    }
}
