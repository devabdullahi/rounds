import Foundation

/// The build's version as the student sees it, read from Info.plist so it never drifts from the build.
enum AppVersion {
    /// "0.1.0 (12)"; just the marketing version when the build number is missing.
    static var display: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let base = (info?["CFBundleVersion"] as? String).map { "\(version) (\($0))" } ?? version
        return isStaging ? "\(base) · test server" : base
    }

    /// True for TestFlight builds archived with the Staging configuration, which talk to the
    /// palpo-staging backend, so a tester (or a screenshot) shows which server they're on.
    static var isStaging: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "RoundsEnvironment") as? String) == "staging"
    }
}
