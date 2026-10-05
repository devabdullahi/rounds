import SwiftUI

// App icons live as SVG files in Assets.xcassets/Icons/ (one image set per icon), not in code.
// Phosphor regular (phosphoricons.com, MIT) plus the three custom tab icons. To change an icon,
// replace its SVG; to add one, drop a new image set in Icons/ and add a case below.
// Assets are vector, rendered as templates, so they take the current foreground color.

enum IconGlyph: String, CaseIterable {
    case hospital = "tab-today"
    case patientChart = "tab-patients"
    case user = "tab-profile"
    case cards = "tab-cards"
    case plus = "plus"
    case shuffle = "shuffle"
    case clock = "clock"
    case chevronLeft = "caret-left"
    case chevronRight = "caret-right"
    case chevronDown = "caret-down"
    case x = "x"
    case flame = "flame"
    case search = "magnifying-glass"
    case circleX = "x-circle"
    case mic = "microphone"
    case arrowUp = "arrow-up"
    case check = "check"
    case circleCheck = "check-circle"
    case share = "export"
    case triangleAlert = "warning"
    case settings = "gear-six"
    case info = "info"
    case award = "medal"
    case messageSquare = "chat-teardrop-text"
    case mail = "envelope-simple"
    case keyRound = "key"
    case timer = "timer"
    case bookOpen = "book-open"
    case activity = "pulse"
    case audioLines = "waveform"
    case gauge = "gauge"
    case eye = "eye"
    case eyeOff = "eye-slash"
    case clipboardList = "clipboard-text"
    case vibrate = "vibrate"
    case bell = "bell"
    case shield = "shield"
    case fileText = "file-text"
    case logOut = "sign-out"
    case circle = "circle"
    case brandMark = "brand-mark"   // the app icon's cross, for in-app branding
    case target = "target"
    case graduationCap = "graduation-cap"
    case externalLink = "arrow-square-out"

    /// Asset catalog name ("Icons" folder provides the namespace).
    var assetName: String { "Icons/\(rawValue)" }
}

struct AppIcon: View {
    let glyph: IconGlyph
    var size: CGFloat = 24

    init(_ glyph: IconGlyph, size: CGFloat = 24) {
        self.glyph = glyph
        self.size = size
    }

    var body: some View {
        Image(glyph.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
