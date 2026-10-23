import SwiftUI

/// One answer in an onboarding question list: a full-width row with a tinted icon (or short text)
/// tile, a title, an optional line under it or value on the right, and a check when picked (a circle
/// for one answer, a box when several can be picked). It fades in `order` rows after the first.
struct ChoiceRow: View {
    let title: String
    var detail: String?
    var trailing: String?
    var glyph: IconGlyph?
    /// Short text in the tile instead of an icon ("MS1", "2").
    var badge: String?
    /// The accent by default; the onboarding questions give each row its own color (`tint(_:)`) so
    /// the lists feel alive.
    var tint: Color = Theme.accentText
    let on: Bool
    var multiple = false
    var order = 0
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tile tints taken in turn down a list, so neighbouring rows differ.
    static let tints: [Color] = [Theme.cardBlue, Theme.cardTeal, Theme.cardPurple, Theme.cardPink, Theme.cardYellow, Theme.cardRed]
    static func tint(_ index: Int) -> Color { tints[index % tints.count] }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : QUESTION.spring) { action() }
        } label: {
            HStack(spacing: 14) {
                if glyph != nil || badge != nil { tile }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .semibold))
                    if let detail {
                        Text(detail).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing {
                    Text(trailing).font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                mark
            }
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: detail == nil ? 60 : 72)
            .modifier(SelectableSurface(on: on))
            .scaleEffect(on && !reduceMotion ? 1.015 : 1)
        }
        .buttonStyle(PressDownStyle())
        .haptic(.selection, trigger: on) { _, now in now }
        .accessibilityAddTraits(on ? .isSelected : [])
        .modifier(QuestionEntrance(order: order))
    }

    /// The row's icon or short text on a soft square of its tint.
    private var tile: some View {
        Group {
            if let glyph {
                AppIcon(glyph, size: 20)
            } else if let badge {
                Text(badge).font(.system(size: 15, weight: .bold))
            }
        }
        .foregroundStyle(tint)
        .frame(width: 40, height: 40)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var mark: some View {
        if multiple {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(on ? Theme.accent : .clear)
                .strokeBorder(on ? Theme.accent : Theme.faint, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay { if on { AppIcon(.check, size: 13).foregroundStyle(Theme.accentInk) } }
                .accessibilityHidden(true)
        } else if on {
            FocusCheck(size: 22)
        }
    }
}
