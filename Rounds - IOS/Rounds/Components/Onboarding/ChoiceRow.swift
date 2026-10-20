import SwiftUI

/// One answer in an onboarding question list: a full-width row with an optional icon, a title, an
/// optional line under it or value on the right, and a check when picked (a circle for one answer,
/// a box when several can be picked).
struct ChoiceRow: View {
    let title: String
    var detail: String?
    var trailing: String?
    var glyph: IconGlyph?
    let on: Bool
    var multiple = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let glyph {
                    AppIcon(glyph, size: 22)
                        .foregroundStyle(on ? Theme.accentText : Theme.muted)
                        .frame(width: 26)
                }
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
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
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
