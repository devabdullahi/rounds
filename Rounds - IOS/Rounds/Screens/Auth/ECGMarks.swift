import SwiftUI

enum ECGMarks {
    /// Wide trace used on First open (342×64).
    static let wide = SVGShape(d: "M0 38 h96 l6 -6 l6 6 h12 l4 5 l7 -40 l7 50 l5 -15 h16 l8 -8 l8 8 h167",
                               viewBox: CGSize(width: 342, height: 64))
    /// Compact mark used on Sign in (120×32).
    static let compact = SVGShape(d: "M0 20 h30 l4 -4 l4 4 h8 l3 3 l4 -22 l4 28 l3 -9 h10 l6 -5 l6 5 h38",
                                  viewBox: CGSize(width: 120, height: 32))
}
