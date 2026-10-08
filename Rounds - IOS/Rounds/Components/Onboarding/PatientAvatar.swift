import SwiftUI

/// A fictional patient in the hero art: the app's initials `Avatar` in a pastel tint, lifted off
/// the page with a white ring and shadow (Rounds never shows faces).
struct PatientAvatar: View {
    let initials: String
    let size: CGFloat
    let tint: AvatarTint

    var body: some View {
        Avatar(initials: initials, size: size, fg: tint.ink, bg: tint.fill)
            .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 4))
            .shadow(color: Theme.text.opacity(0.12), radius: 12, y: 8)
    }
}
