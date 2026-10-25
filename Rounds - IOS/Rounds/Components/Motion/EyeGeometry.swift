import SwiftUI

/// Where one eye sits, in the head's own coordinates.
struct EyeGeometry: Sendable {
    var cx: CGFloat, cy: CGFloat
    /// Size of the eye white (a pill).
    var w: CGFloat, h: CGFloat
    /// Pupil size, and its top edge measured from the top of the eye white.
    var pupilW: CGFloat, pupilH: CGFloat, pupilTop: CGFloat
    /// Radius of the highlight dot. 0 for none.
    var shine: CGFloat
    init(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, pupilW: CGFloat, pupilH: CGFloat, pupilTop: CGFloat, shine: CGFloat) {
        self.cx = cx; self.cy = cy; self.w = w; self.h = h
        self.pupilW = pupilW; self.pupilH = pupilH; self.pupilTop = pupilTop; self.shine = shine
    }
}
