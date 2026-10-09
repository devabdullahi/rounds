import Foundation

/// The build's version as the student sees it, read from Info.plist so it never drifts from the build.
enum AppVersion {
    /// "0.1.0 (12)"; just the marketing version when the build number is missing.
    static var display: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}
