import CoreGraphics

/// One frame of a `DoctorFigure`: where the eyes look, how far the lids are down, the smile,
/// the head's tilt and the body's breath. Scenes work these out from their clock and hand them over.
struct FigurePose {
    /// Pupil offset, in the figure's 100-unit space.
    var lookX: CGFloat = 0
    var lookY: CGFloat = 0
    /// Upper eyelid, 0 open to 1 closed.
    var lid: CGFloat = 0
    /// Happy squint, 0 to 1.
    var cheek: CGFloat = 0
    /// Mouth curve, -1 a frown to 1 a smile.
    var smile: CGFloat = 0.3
    /// Head rotation around the neck, in degrees.
    var tilt: CGFloat = 0
    /// How far the whole figure has risen with the breath, in points.
    var breath: CGFloat = 0
    /// A sideways nudge, in points (a nervous tremble).
    var dx: CGFloat = 0
}
