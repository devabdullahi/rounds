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
        let job = Task { @MainActor in await work() }
        // If iOS runs out of background time, give it back (cancelling the work) instead of being killed.
        let background = BackgroundTime(name: "Rounds intent") { job.cancel() }
        let early: Bool? = await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await job.value }
            group.addTask { try? await Task.sleep(for: limit); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if early != nil {
            background.end()
        } else {
            Task { @MainActor in
                await later(await job.value)
                background.end()
            }
        }
        return early
    }

    /// How long Siri waits on a deck before the app says it'll notify instead.
    static let deckWait: Duration = .seconds(20)
}

/// A stretch of background time from iOS that ends exactly once: when the work finishes, or when
/// iOS says time is up (then `onExpire` runs first).
@MainActor
private final class BackgroundTime {
    private var id = UIBackgroundTaskIdentifier.invalid

    init(name: String, onExpire: @escaping @MainActor () -> Void) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated {
                onExpire()
                self?.end()
            }
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
