import SwiftUI

enum STACK {
    static let visible = 3
    static let depthOffset: CGFloat = 14      // pt each card peeks out below the one above
    static let depthScale: CGFloat = 0.05
    static let cardHeight: CGFloat = 436      // one big card owns the screen (Avec-style focus)
    static let restack = Animation.spring(response: 0.45, dampingFraction: 0.82)
}
