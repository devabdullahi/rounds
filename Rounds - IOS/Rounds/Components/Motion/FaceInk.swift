import SwiftUI

struct FaceInk: Sendable {
    var white: Color, pupil: Color
    /// The skin colour: eyelid and cheek are skin sliding over the white.
    var skin: Color
    /// Lines: lash edge, closed eye, happy-squint arc.
    var line: Color
    var lineWidth: CGFloat
    init(white: Color, pupil: Color, skin: Color, line: Color, lineWidth: CGFloat = 5) {
        self.white = white; self.pupil = pupil; self.skin = skin; self.line = line; self.lineWidth = lineWidth
    }
}
