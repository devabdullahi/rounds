import SwiftUI

/// The badge's mark: colored when earned; dimmed with a lock on top when not.
struct BadgeMedallion: View {
    let status: BadgeStatus
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(status.unlocked ? Theme.accent.opacity(0.16) : Theme.text.opacity(0.06))
            Circle()
                .strokeBorder(status.unlocked ? Theme.accent.opacity(0.55) : Theme.text.opacity(0.10), lineWidth: 2)
            Image(badge: status.badge.art)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundStyle(status.unlocked ? Theme.accent : Theme.faint)
                .opacity(status.unlocked ? 1 : 0.45)
            if !status.unlocked {
                // The lock sits on the badge, as on a console achievement list.
                AppIcon(.lock, size: size * 0.2)
                    .foregroundStyle(.white)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(Theme.faint, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
        .frame(width: size, height: size)
    }
}
