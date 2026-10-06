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
            } else {
                BadgeCardBack(progress: status.progress, label: status.compactProgressLabel)
            }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: Self.size.width * scale, height: Self.size.height * scale, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.badge.name), \(status.badge.rarity.label) card, "
                            + (status.unlocked ? "collected" : "locked, \(status.progressLabel)"))
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

/// An earned card: name bar and rarity gem, art window, type line, how it was earned, set number.
struct BadgeCardFront: View {
    let status: BadgeStatus
    private var ink: Color { status.badge.rarity.ink }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(status.badge.name)
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Rectangle().fill(ink).frame(width: 10, height: 10).rotationEffect(.degrees(45))
                    .shadow(color: ink, radius: 3)
            }
            .padding(.horizontal, 4)
            .frame(height: 20)

            ZStack {
                RadialGradient(colors: [ink.opacity(0.38), Theme.cardBack], center: .init(x: 0.5, y: 0.45),
                               startRadius: 4, endRadius: 90)
                ECGShape(beats: 1, stElevation: false)
                    .stroke(ink.opacity(0.35), lineWidth: 1.5)
                    .frame(height: 26)
                    .offset(y: 26)
                AppIcon(status.badge.glyph, size: 54)
                    .foregroundStyle(.white)
                    .shadow(color: ink, radius: 8)
            }
            .frame(height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ink, lineWidth: 1))

            HStack {
                Text(status.badge.group.label.uppercased())
                Spacer()
                Text(status.badge.rarity.label.uppercased())
            }
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(ink)
            .padding(.horizontal, 4)

            Text(status.badge.detail)
                .font(.system(size: 10.5))
                .lineSpacing(2)
                .foregroundStyle(Theme.cardInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack {
                Text(status.setNumber)
                Spacer()
                Text("ROUNDS")
            }
            .font(.mono(9, weight: .medium))
            .foregroundStyle(Theme.rarityCommon)
            .padding(.horizontal, 4)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: BadgeCard.size.width, height: BadgeCard.size.height)
        .background(LinearGradient(colors: [Theme.cardStock, Theme.cardBack], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if status.badge.rarity.hasFoil { CardFoil(ink: ink) }
        }
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ink, lineWidth: 2))
        .shadow(color: ink.opacity(0.3), radius: 9)
    }
}

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

/// Holographic foil: a soft band of color that drifts across the card. Continuous motion, so it
/// runs on a timeline that pauses under Reduce Motion (the band then rests mid-card).
private struct CardFoil: View {
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum FOIL {
        static let period = 3.2   // s per drift across and back
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.5 : (sin(t / FOIL.period * 2 * .pi) + 1) / 2
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: ink.opacity(0.28), location: 0.42),
                    .init(color: .white.opacity(0.22), location: 0.5),
                    .init(color: Theme.info.opacity(0.22), location: 0.58),
                    .init(color: .clear, location: 1),
                ],
                startPoint: UnitPoint(x: -0.6 + phase * 1.2, y: 0),
                endPoint: UnitPoint(x: 0.4 + phase * 1.2, y: 1)
            )
            .blendMode(.screen)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
    }
}
