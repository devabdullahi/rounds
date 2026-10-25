#if DEBUG
import SwiftUI

/// Dev-only deep link for screenshots: launch with `-screen <name>`.
/// Names: firstopen, firstopen-auth, duplicate-account, voice-glass, onboarding (year), onboarding-year, onboarding-goal, onboarding-reason,
/// onboarding-practice, onboarding-practice-other, onboarding-blanked, onboarding-blanked-reply, onboarding-blanked-sometimes, onboarding-blanked-rarely, onboarding-exam, onboarding-countdown, onboarding-study-time, onboarding-pace, onboarding-setting-up, onboarding-plan,
/// onboarding-confidence, onboarding-reality,
/// onboarding-account, onboarding-heard, onboarding-heart, onboarding-promised (every `onboarding…` name opens onboarding),
/// settings-about, paywall, paywall-plans, purchased, reminders, paywall-unavailable, paywall-delete,
/// focus-system, focus-sheet, home, patients, patients-new, patients-seen, patients-open, previous-tries, previous-try, badge-unlock-many, badge-unlock-all, paywall-taken, plan-checking, profile, brief, interview, interview-nudge, interview-ideas, examine, workup, diagnosis, debrief, debrief-graded, debrief-deeper (graded, last card, every section open), debrief-tour (graded, steps through every card), diagnosis-suggest.
enum DebugLaunch {
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }
    /// `-screen voice-glass` shows `VoiceGlassDebugView` in place of the app.
    static var isVoiceGlass: Bool { screen == "voice-glass" }

    /// `-hr 130` previews the Home monitor at another heart rate.
    static var heartRate: Int? {
        let v = UserDefaults.standard.integer(forKey: "hr")
        return v > 0 ? v : nil
    }

    /// Screens that stay on the paywall (no debug unlock): Superwall's, the "plans couldn't load"
    /// fallback, the delete confirmation over it, and the plan-owned-by-another-account state.
    static let paywallScreens: Set<String> = ["paywall", "paywall-plans", "paywall-taken", "paywall-unavailable", "paywall-delete", "plan-checking"]
    /// `-screen paywall-unavailable`: the fallback in place of Superwall's paywall.
    static var isPaywallUnavailable: Bool { screen == "paywall-unavailable" }

    private static let authScreens = ["firstopen", "firstopen-auth", "duplicate-account", "focus-system", "google-signin"]

    /// Every `onboarding…` screen opens onboarding, signed out.
    private static func isAuthScreen(_ name: String) -> Bool { name.hasPrefix("onboarding") || authScreens.contains(name) }

    /// Runs before the first frame so the root picks the right side (auth vs app).
    static func prepareDefaults() {
        guard let screen else { return }
        let d = UserDefaults.standard
        d.set(!isAuthScreen(screen), forKey: AuthModel.signedInKey)
        // App screens open with the consent given (as after signing in); onboarding starts without it.
        let consented = !isAuthScreen(screen)
        d.set(consented ? AIConsent.agreed : AIConsent.withdrawn, forKey: AIConsent.storageKey)
        if ["onboarding-heart", "onboarding-promised"].contains(screen) || paywallScreens.contains(screen) {
            d.set(StudyGoal.step2CK.rawValue, forKey: StudyGoal.storageKey)
            d.set(StudyFocus.rotation(.internalMedicine).stored, forKey: StudyFocus.storageKey)
        }
        if ["focus-sheet", "home", "settings", "settings-siri", "settings-voice", "settings-about", "settings-subscription"].contains(screen) {
            d.set(StudyFocus.rotation(.internalMedicine).stored, forKey: StudyFocus.storageKey)
        }
    }

    /// Fictional signed-in student for screenshots of account screens.
    static let sampleAccount = Account(id: "debug", email: "maya.patel@school.edu", name: "Maya Patel",
                                       provider: "google", createdAt: .now,
                                       specialty: .emergencyMedicine, onboarded: true)

    static var authPath: [AuthStep] {
        switch screen {
        case let name? where name.hasPrefix("onboarding") || name == "focus-system": [.onboarding]
        default: []
        }
    }

    @MainActor static func apply(app: AppState, tab: inout Tab, expandedPatient: inout String?) {
        guard let screen else { return }
        switch screen {
        case "patients", "patients-new", "patients-seen", "previous-tries", "previous-try": tab = .patients
        case "cards", "cards-flip", "cards-correct", "cards-unknown", "cards-new", "cards-new-color", "cards-new-answer",
             "cards-add", "cards-generate", "cards-generate-notes", "cards-generate-notes-pick", "cards-generate-mistakes": tab = .cards
        case "patients-open": tab = .patients; expandedPatient = "R2"
        case "profile", "settings", "settings-siri", "settings-voice", "settings-about", "settings-subscription", "profile-weakspots", "profile-badges", "profile-edit": tab = .profile
        case "home", "focus-sheet", "splash", "home-swipe-right", "home-swipe-left": tab = .today
        case "home-empty":
            tab = .today
            app.debugEmptyWard = true
        case "patients-select", "patients-swipe", "patients-swipe-left", "patients-delete":
            tab = .patients
            app.debugPatientsMode = ["patients-select": "select", "patients-delete": "delete"][screen] ?? "swipe"
            if screen == "patients-swipe-left" { SwipeToDelete.debugOpenSide = -1 }
        case "badge-unlock":
            tab = .profile
            app.debugUnlockRandomBadge()
        case "badge-unlock-many", "badge-unlock-all":
            tab = .profile
            app.debugUnlockSeveral(4)
            app.showingAllUnlocks = screen == "badge-unlock-all"
        case "badge-unlock-beginning":
            tab = .profile
            app.debugUnlock(BadgeCatalog.beginningID)
        case let name where name.hasPrefix("home-streak-"):
            tab = .today
            // home-streak-12 shows a 12-day streak; home-streak-12-open also opens the spotlight.
            let parts = name.dropFirst("home-streak-".count).split(separator: "-")
            app.debugStreak = parts.first.flatMap { Int($0) }
            app.showingStreak = parts.last == "open"
        case "home-preparing":
            tab = .today
            app.debugShowPreparing()
        case "purchased", "reminders":
            // The welcome after buying shows over Home (RootView).
            tab = .today
        case "admit":
            // Generates a live patient (the AI model via local Supabase) and opens its door note.
            tab = .today
            Task { @MainActor in await app.admit(focus: FocusSelection()) }
        default:
            // Case screens open the newest generated patient (admit one first from Home).
            let path: [CaseStep]
            switch screen {
            case "interview", "interview-nudge", "interview-ideas", "interview-exam", "interview-findings", "voice-listen", "voice-patient", "voice-live", "examine", "workup": path = [.interview]
            case "diagnosis", "diagnosis-suggest", "diagnosis-ddx", "diagnosis-ddx-add": path = [.interview, .diagnosis]
            case "handoff": path = [.interview, .diagnosis, .handoff]
            case "debrief", "debrief-graded", "debrief-deeper", "debrief-tour": path = [.interview, .diagnosis, .handoff, .debrief]
            default: path = []
            }
            app.debugInitialPath = path
            Task { @MainActor in
                await app.refresh()
                if let newest = app.ward.first { await app.open(bed: newest.id) }
            }
        }
    }
}
#endif
