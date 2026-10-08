import SwiftUI

enum Springs {
    static let card   = Animation.spring(response: 0.45, dampingFraction: 0.85)  // smooth settle
    static let pop    = Animation.spring(response: 0.3, dampingFraction: 0.65)   // badges, chips
    static let slide  = Animation.spring(response: 0.4, dampingFraction: 0.8)    // entrances
}
