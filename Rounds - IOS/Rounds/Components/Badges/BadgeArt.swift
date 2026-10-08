import SwiftUI

/// Badge artwork from game-icons.net (CC BY 3.0), white template images in `Assets.xcassets/Badges`.
/// Each icon's artist is credited in Settings › Acknowledgements (`credits`).
enum BadgeArt: String, CaseIterable, Sendable {
    case sportMedal = "badge-sport-medal", jewelCrown = "badge-jewel-crown"
    case stethoscope = "badge-stethoscope", personInBed = "badge-person-in-bed"
    case threeFriends = "badge-three-friends", hospitalCross = "badge-hospital-cross"
    case ruleBook = "badge-rule-book", targetArrows = "badge-target-arrows"
    case magnifyingGlass = "badge-magnifying-glass", microscope = "badge-microscope"
    case focusedLightning = "badge-focused-lightning", siren = "badge-siren"
    case healingShield = "badge-healing-shield", laurelCrown = "badge-laurel-crown"
    case flame = "badge-flame", nightSky = "badge-night-sky", sunrise = "badge-sunrise"
    case fluffyFlame = "badge-fluffy-flame", fireGem = "badge-fire-gem", flameSpin = "badge-flame-spin"
    case trophy = "badge-trophy", compass = "badge-compass", treasureMap = "badge-treasure-map"
    case targetPrize = "badge-target-prize", dna = "badge-dna2"
    case tiedScroll = "badge-tied-scroll", scrollQuill = "badge-scroll-quill"
    case eyeTarget = "badge-eye-target", brainstorm = "badge-brainstorm"
    case nightVision = "badge-night-vision", stopwatch = "badge-stopwatch", starMedal = "badge-star-medal"

    /// The artist the license asks to be credited for this icon.
    var artist: String {
        switch self {
        case .flame: "Carl Olsen"
        case .microscope: "Lord Berandas"
        case .siren: "Skoll"
        case .hospitalCross, .targetArrows, .magnifyingGlass, .focusedLightning, .laurelCrown, .nightSky,
             .fluffyFlame, .flameSpin, .trophy, .compass, .treasureMap, .dna, .tiedScroll, .brainstorm, .stopwatch:
            "Lorc"
        default: "Delapouite"
        }
    }

    /// Artists whose icons appear, for the acknowledgements screen.
    static var credits: [String] { Array(Set(allCases.map(\.artist))).sorted() }
}

extension Image {
    /// A badge's artwork, tinted by `foregroundStyle`.
    init(badge art: BadgeArt) { self.init(art.rawValue) }
}
