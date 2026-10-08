import AppIntents
import UIKit

/// What every Rounds intent shares: the signed-in check, the student's saved focus, and running
/// slow work past Siri's patience.
@MainActor
enum IntentSupport {
    /// Intents act on the student's account, so they wait until someone has signed in on this
    /// device (otherwise the case service would quietly start a guest session).
    static var isSignedIn: Bool { UserDefaults.standard.bool(forKey: "signedIn") }
    static let signInFirst: IntentDialog = "Open Rounds and sign in first."

    /// The focus the student picked in the app, or a mix.
    static var savedFocus: FocusSelection {
        FocusSelection(stored: UserDefaults.standard.string(forKey: StudyFocus.storageKey) ?? "")
    }

    /// The focus a spoken topic means, or the saved one when none was said.
    static func focus(_ topic: IntentTopic?) -> FocusSelection {
        topic.map { FocusSelection([$0.focus]) } ?? savedFocus
    }

    /// Runs `work`, waiting up to `limit` for its result. Past that it keeps going on background
    /// time from iOS and hands its result to `later` instead; nil means it's still running.
    static func run(waitingUpTo limit: Duration, _ work: @escaping @MainActor () async -> Bool,
                    later: @escaping @MainActor (Bool) async -> Void) async -> Bool? {
        let background = UIApplication.shared.beginBackgroundTask(withName: "Rounds intent")
        let job = Task { @MainActor in await work() }
        let early: Bool? = await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await job.value }
            group.addTask { try? await Task.sleep(for: limit); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if early != nil {
            UIApplication.shared.endBackgroundTask(background)
        } else {
            Task { @MainActor in
                await later(await job.value)
                UIApplication.shared.endBackgroundTask(background)
            }
        }
        return early
    }

    /// How long Siri waits on a deck before the app says it'll notify instead.
    static let deckWait: Duration = .seconds(20)
}
