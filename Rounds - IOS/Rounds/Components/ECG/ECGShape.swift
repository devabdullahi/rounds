import SwiftUI

/// Lead II trace: `beats` evenly spaced PQRST complexes across a 354×40 grid.
/// `stElevation` lifts the ST segment into a tombstone T wave, as in inferior leads of an STEMI.
/// Zero beats draws a flatline (asystole).
struct ECGShape: Shape {
    var beats: Int = 3
    var stElevation = false

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 354, sy = rect.height / 40
        guard beats > 0 else {
            var flat = Path()
            flat.move(to: CGPoint(x: 0, y: 26 * sy))
            flat.addLine(to: CGPoint(x: rect.width, y: 26 * sy))
            return flat
        }
        let cell = 354 / CGFloat(beats)
        let k = ECG.complexScale(cell)
        var p = Path()
        var x: CGFloat = 0
        func to(_ dx: CGFloat, _ y: CGFloat) { x += dx * k; p.addLine(to: CGPoint(x: x * sx, y: y * sy)) }
        p.move(to: CGPoint(x: 0, y: 26 * sy))
        for b in 0..<beats {
            x = CGFloat(b) * cell + ECG.beatLead * cell
            p.addLine(to: CGPoint(x: x * sx, y: 26 * sy))
            to(5, 21); to(5, 26); to(10, 26); to(3, 30)       // P, PR, Q
            to(5, 2); to(5, 36)                               // R, S
            if stElevation {
                to(4, 17); to(11, 15); to(7, 11); to(8, 26)   // J point → raised ST → T
            } else {
                to(4, 26); to(12, 26); to(7, 19); to(7, 26)
            }
        }
        p.addLine(to: CGPoint(x: 354 * sx, y: 26 * sy))
        return p
    }
}
