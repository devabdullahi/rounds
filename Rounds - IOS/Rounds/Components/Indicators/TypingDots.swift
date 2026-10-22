import SwiftUI

private enum DOTS {
    static let stagger = 0.15               // s between dot bounces
    static let lift: CGFloat = 4            // px each dot hops
    static let period = 0.9                 // s per bounce cycle
}

/// Three hopping dots in a patient bubble: the patient is answering. Still under Reduce Motion.
struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t - Double(i) * DOTS.stagger).truncatingRemainder(dividingBy: DOTS.period) / DOTS.period
                    Circle()
                        .fill(Theme.faint)
                        .frame(width: 7, height: 7)
                        .offset(y: reduceMotion ? 0 : -DOTS.lift * max(0, sin(phase * .pi * 2)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityLabel("Patient is answering")
    }
}
