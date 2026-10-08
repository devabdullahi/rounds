import SwiftUI

// Shared pieces of the new-student onboarding (intro pages, study goal, promise): the segmented
// progress bar, the round back button, the fixed-size hero canvas the art is laid out on, and
// the small decorative parts the heroes are drawn from. All take plain values and closures.

// MARK: - Chrome

/// Back button plus a segmented progress bar, filled up to `current` (1-based).
struct OnboardingTopBar: View {
    let total: Int
    let current: Int
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onBack {
                IconButton(glyph: .chevronLeft, label: "Back", quiet: true, action: onBack)
                    .padding(.leading, -10)
            }
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { i in
                    Capsule()
                        .fill(i <= current ? Theme.text : Theme.control)
                        .frame(height: 4)
                }
            }
            .animation(.easeOut(duration: 0.25), value: current)
            .accessibilityElement()
            .accessibilityLabel("Step \(current) of \(total)")
        }
        .frame(height: 44)
    }
}

/// Big centered headline under the hero.
struct OnboardingHeadline: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .bold))
            .tracking(-0.6)
            .multilineTextAlignment(.center)
            .lineSpacing(-2)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(1)   // read before the art and choices above it
    }
}

/// Centered pill action with a trailing arrow.
struct OnboardingNextButton: View {
    var title = "Next"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                AppIcon(.arrowRight, size: 18)
            }
        }
        .buttonStyle(PrimaryButtonStyle(height: 60))
        .frame(width: 230)
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}

/// Soft colour wash fading to the page colour, behind the hero art.
struct HeroWash: View {
    var tint: Color = Theme.heroMint
    var body: some View {
        LinearGradient(stops: [.init(color: tint, location: 0), .init(color: tint.opacity(0.45), location: 0.42),
                               .init(color: Theme.surface, location: 0.64)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Hero canvas

/// The fixed 350×400 board (the design's frame) hero art is laid out on, and how it scales
/// into the space a screen gives it, so every element keeps its place on any phone.
enum HeroBoard {
    static let size = CGSize(width: 350, height: 400)
    /// Never blown up past 115%, or the art outgrows the headline on large phones.
    static let maxScale: CGFloat = 1.15

    static func scale(in space: CGSize) -> CGFloat {
        min(space.width / size.width, space.height / size.height, maxScale)
    }

    /// Top-left corner of the scaled board, centred in `space`.
    static func origin(in space: CGSize) -> CGPoint {
        let s = scale(in: space)
        return CGPoint(x: (space.width - size.width * s) / 2, y: (space.height - size.height * s) / 2)
    }
}

/// Decorative hero art drawn on the HeroBoard. Hidden from VoiceOver: the headline says it.
struct HeroCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) { content }
                .frame(width: HeroBoard.size.width, height: HeroBoard.size.height, alignment: .topLeading)
                .scaleEffect(HeroBoard.scale(in: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Places a hero element by its top-left corner on the 350×400 board.
    func at(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }

    /// Hero elements pop in: scale 0.85 → 1 and fade, after `delay`. Reduce Motion shows them at once.
    func heroPop(_ shown: Bool, delay: Double) -> some View { modifier(HeroPop(shown: shown, delay: delay)) }
}

private struct HeroPop: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .animation(reduceMotion ? nil : Springs.pop.delay(delay), value: shown)
    }
}

// MARK: - Art parts

/// Four-point sparkle, the hero art's accent mark.
struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + r.width * 0.06, y: c.y - r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + r.width * 0.06, y: c.y + r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - r.width * 0.06, y: c.y + r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - r.width * 0.06, y: c.y - r.height * 0.06))
        return p
    }
}

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

/// Small dark capsule holding one icon, floating in the hero art.
struct IconPill: View {
    let glyph: IconGlyph
    var body: some View {
        AppIcon(glyph, size: 20)
            .foregroundStyle(Theme.surface)
            .frame(width: 46, height: 40)
            .background(Theme.text, in: Capsule())
            .shadow(color: Theme.text.opacity(0.2), radius: 10, y: 6)
    }
}

/// White label bubble with a soft shadow.
struct HeroTag: View {
    let text: String
    var ink: Color = Theme.text
    var fill: Color = Theme.surface
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.text.opacity(0.08), radius: 10, y: 6)
    }
}

/// Filled green check in a circle.
struct CheckDot: View {
    var size: CGFloat = 24
    var body: some View {
        AppIcon(.check, size: size * 0.55)
            .foregroundStyle(Theme.accentInk)
            .frame(width: size, height: size)
            .background(Theme.accent, in: Circle())
    }
}
