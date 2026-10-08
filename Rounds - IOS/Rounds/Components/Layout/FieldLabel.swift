import SwiftUI

/// Small sentence-case label for fields and in-card sections. All-caps `Eyebrow` is reserved for
/// true section headers outside cards, so labels don't all shout at the same volume.
struct FieldLabel: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
    }
}
