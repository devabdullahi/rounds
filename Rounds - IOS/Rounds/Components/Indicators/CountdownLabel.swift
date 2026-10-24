import SwiftUI

/// Timer stays quiet until it matters.
private enum TIMER {
    static let warnBelow: TimeInterval = 120   // turns coral
    static let pulseBelow: TimeInterval = 30   // starts pulsing
}

struct CountdownLabel: View {
    let session: CaseSession
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            if session.isTimed {
                let remaining = session.remaining(at: ctx.date)
                let urgent = remaining <= TIMER.warnBelow
                let critical = remaining <= TIMER.pulseBelow
                let pulseOn = critical && remaining > 0 && Int(remaining) % 2 == 0
                // At zero the clock says so in words: a red 00:00 read as a broken timer.
                Text(remaining > 0 ? CaseSession.format(remaining) : "Time's up")
                    .font(remaining > 0 ? .mono(17) : .system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(urgent ? Theme.warn : Theme.dim)
                    .opacity(pulseOn ? 0.55 : 1)
                    .animation(.easeInOut(duration: 0.5), value: pulseOn)
                    .padding(.trailing, 8)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel(remaining > 0 ? "\(Int(remaining) / 60) minutes \(Int(remaining) % 60) seconds left" : "Time's up")
            } else {
                // Untimed: count up quietly, never turns urgent.
                let elapsed = session.elapsed(at: ctx.date)
                Text(CaseSession.format(elapsed))
                    .font(.mono(17))
                    .foregroundStyle(Theme.faint)
                    .padding(.trailing, 8)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(Int(elapsed) / 60) minutes \(Int(elapsed) % 60) seconds elapsed, untimed")
            }
        }
    }
}
