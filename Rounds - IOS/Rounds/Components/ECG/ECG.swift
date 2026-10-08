import SwiftUI

enum ECG {
    static let nominalWindow = 2.4       // s per sweep before snapping to whole beats
    static let tail: CGFloat = 0.55      // fraction of the width the fading trail covers
    static let complexWidth: CGFloat = 63   // P through T, in 354-unit trace space
    static let beatLead: CGFloat = 0.3   // where in each beat cell the P wave starts
    static let rOffset: CGFloat = 28     // P (10) + PR (10) + Q (3) + upstroke (5)
    static let lineWidth: CGFloat = 1.8

    /// Whole beats per sweep, so the trace repeats seamlessly when the head wraps.
    static func beatsPerSweep(_ bpm: Double) -> Int { max(2, Int((bpm * nominalWindow / 60).rounded())) }
    static func window(_ bpm: Double) -> Double { Double(beatsPerSweep(bpm)) * 60 / bpm }

    /// Seconds since the sweep head last crossed an R wave: drives heartbeat-synced effects.
    static func timeSinceBeat(at date: Date, bpm: Double) -> Double {
        let cell = 60 / bpm
        let n = CGFloat(beatsPerSweep(bpm))
        let cellUnits = 354 / n
        let k = complexScale(cellUnits)
        let rFraction = Double((ECG.beatLead * cellUnits + rOffset * k) / cellUnits)
        let phase = date.timeIntervalSinceReferenceDate / cell - rFraction
        return (phase - phase.rounded(.down)) * cell
    }

    /// Shrinks the complex so P→T ends inside its own cell, after the lead-in, with a short
    /// baseline before the next beat. Without this the last T wave overruns the right edge.
    static func complexScale(_ cellUnits: CGFloat) -> CGFloat {
        min(1, (cellUnits * (1 - beatLead) - 8) / complexWidth)
    }
}
