import SwiftUI

enum DECK {
    static let visible = 3                     // cards drawn in the stack
    static let depthOffset: CGFloat = 12       // pt each card peeks out below the one above
    static let depthScale: CGFloat = 0.045     // scale lost per depth step
    static let dealFrom: CGFloat = 640         // pt below the stack: starts under the screen edge
    static let fan: Double = 10                // ° spread while dealing
    static let deal = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let cardHeight: CGFloat = 380
}
