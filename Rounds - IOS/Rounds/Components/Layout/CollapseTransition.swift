import SwiftUI

/// A deleted row's exit: it shrinks away from the bottom while the rows below move up into its
/// place, instead of vanishing and letting them jump.
struct CollapseTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .mask(alignment: .top) {
                Rectangle().scaleEffect(x: 1, y: phase.isIdentity ? 1 : 0.001, anchor: .top)
            }
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

extension AnyTransition {
    static let collapse = AnyTransition(CollapseTransition())
}
