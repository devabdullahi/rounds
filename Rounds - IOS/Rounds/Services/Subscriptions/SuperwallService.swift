import Foundation
import SuperwallKit

/// Superwall: the paywalls students see, designed and priced in Superwall's dashboard. It buys
/// through StoreKit 2, so `StoreKitSubscriptionStore` sees every purchase it makes. The public API
/// key comes from `SUPERWALL_API_KEY` in Secrets.xcconfig; without it Superwall stays off and the
/// paywall screen says it can't load.
enum SuperwallService {
    /// The campaign placement shown when a signed-in student has no plan. Must match the dashboard.
    static let gatePlacement = "app_gate"

    /// True once `configure()` has run with a key.
    @MainActor static var isConfigured: Bool { Superwall.isInitialized }

    /// Starts Superwall once, at launch. Does nothing without a key.
    @MainActor static func configure() {
        // Unit tests run inside the app; they must not start Superwall or touch the network.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !Superwall.isInitialized,
              let key = Bundle.main.object(forInfoDictionaryKey: "SuperwallAPIKey") as? String,
              key.hasPrefix("pk_") else { return }
        let options = SuperwallOptions()
        options.storeKitVersion = .storeKit2
        Superwall.configure(apiKey: key, options: options)
    }

    /// Opens Superwall's own links (on-device paywall previews from the dashboard, which arrive on
    /// the rounds:// scheme). False for any other link, which the app handles itself.
    @MainActor static func handle(_ url: URL) -> Bool {
        guard Superwall.isInitialized else { return false }
        return Superwall.handleDeepLink(url)
    }

    /// Audience targeting: the exam the student said they're studying for ("step2CK"). Nothing
    /// personal (no name or email) goes to Superwall.
    @MainActor static func setStudyGoal(_ goal: String) {
        guard Superwall.isInitialized else { return }
        Superwall.shared.setUserAttributes(["study_goal": goal.isEmpty ? nil : goal])
    }

    /// Ties purchases and analytics to the Rounds account, or forgets the last one on sign-out.
    @MainActor static func identify(_ accountID: String?) {
        guard Superwall.isInitialized else { return }
        if let accountID { Superwall.shared.identify(userId: accountID) } else { Superwall.shared.reset() }
    }
}

extension PurchasedPlan {
    /// What the app keeps from Superwall's product.
    init(_ product: StoreProduct) {
        let period: PlanPeriod? = switch (product.subscriptionPeriod?.unit, product.subscriptionPeriod?.value) {
        case (.week?, 1?): .week
        case (.month?, 1?): .month
        case (.year?, 1?): .year
        default: nil
        }
        self.init(displayPrice: product.localizedPrice, period: period,
                  trialDays: product.hasFreeTrial ? product.trialPeriodDays : nil)
    }
}
