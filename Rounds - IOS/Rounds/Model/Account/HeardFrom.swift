import Foundation

/// Where a new student heard about Rounds, asked once in onboarding (skippable). Kept on the
/// phone for now.
enum HeardFrom: String, CaseIterable, Identifiable {
    case friend, tiktok, instagram, reddit, youtube, school, appStore, other

    static let storageKey = "heardFrom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .friend: "Classmate or friend"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .reddit: "Reddit"
        case .youtube: "YouTube"
        case .school: "My school or a student group"
        case .appStore: "App Store search"
        case .other: "Something else"
        }
    }
}
