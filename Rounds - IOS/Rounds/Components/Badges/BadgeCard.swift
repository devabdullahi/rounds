import SwiftUI

/// A badge as a trading card: the front once earned, the card back with a lock and progress until
/// then. Drawn at 180×252 (5:7) and scaled, so every size keeps the same proportions.
struct BadgeCard: View {
    let status: BadgeStatus
    var scale: CGFloat = 1

    static let size = CGSize(width: 180, height: 252)

    var body: some View {
        Group {
            if status.unlocked {
                BadgeCardFront(status: status)
            } else if status.hidden {
                BadgeCardBack(progress: nil, secret: true)
            } else {
                BadgeCardBack(progress: status.progress, label: status.toGoLabel)
            }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: Self.size.width * scale, height: Self.size.height * scale, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.hidden ? "Secret card, locked"
                            : "\(status.badge.name), \(status.badge.rarity.label) card, "
                            + (status.unlocked ? "collected" : "locked, \(status.toGoLabel)"))
    }
}

extension Badge.Rarity {
    /// The card's ink: frame, gem, type line and glow.
    var ink: Color {
        switch self {
        case .common: Theme.rarityCommon
        case .rare: Theme.rarityRare
        case .epic: Theme.rarityEpic
        case .legendary: Theme.rarityLegendary
        }
    }
}
