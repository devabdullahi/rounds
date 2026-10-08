import SwiftUI

/// The back every card shares: a woven pattern with the Rounds cross, plus a lock and progress
/// while the badge is still locked.
struct BadgeCardBack: View {
    /// 0…1 toward the goal; nil shows a plain back (the unlock animation's first face).
    var progress: Double?
    var label: String = ""

    var body: some View {
        ZStack {
            Canvas { context, size in
                // Two sets of diagonals, 14pt apart: card-back weave.
                var path = Path()
                stride(from: -size.height, through: size.width, by: 14).forEach { x in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                }
                context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 2)
            }
            VStack(spacing: 10) {
                AppIcon(.brandMark, size: 34)
                    .foregroundStyle(Theme.faint)
                    .frame(width: 74, height: 74)
                    .background(Theme.cardBack, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 2))
                Text("ROUNDS").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Theme.faint)
            }
            if let progress {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        AppIcon(.lock, size: 13)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.14), in: Circle())
                        ProgressBar(value: progress, color: Theme.rarityCommon, height: 5)
                        Text(label)
                            .font(.mono(11, weight: .semibold))
                            .foregroundStyle(Theme.cardInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: BadgeCard.size.width, height: BadgeCard.size.height)
        .background(Theme.cardBack, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 2))
    }
}
