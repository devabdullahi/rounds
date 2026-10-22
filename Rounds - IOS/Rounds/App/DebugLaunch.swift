#if DEBUG
import SwiftUI

/// Dev-only deep link for screenshots: launch with `-screen <name>`.
/// Names: firstopen, firstopen-auth, duplicate-account, voice-glass, onboarding (focus), onboarding-account, onboarding-intro, onboarding-try, onboarding-graded,
/// onboarding-promise, onboarding-graph, onboarding-goal, onboarding-to-goal, onboarding-year, onboarding-name, onboarding-setting, onboarding-cards, onboarding-reminder, onboarding-struggles, onboarding-talk, onboarding-timer, onboarding-progress, onboarding-daily, onboarding-plan, onboarding-heart, onboarding-promised,
/// settings-about, onboarding-consent, ai-consent, paywall, paywall-unavailable, paywall-delete,
/// focus-system, focus-sheet, home, patients, patients-open, previous-tries, previous-try, badge-unlock-many, badge-unlock-all, paywall-taken, plan-checking, profile, brief, interview, examine, workup, diagnosis, debrief, diagnosis-suggest.
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
    static let paywallScreens: Set<String> = ["paywall", "paywall-taken", "paywall-unavailable", "paywall-delete", "plan-checking"]
    /// `-screen paywall-unavailable`: the fallback in place of Superwall's paywall.
    static var isPaywallUnavailable: Bool { screen == "paywall-unavailable" }

    private static let authScreens = ["firstopen", "firstopen-auth", "duplicate-account", "onboarding", "focus-system", "google-signin",
                                      "onboarding-intro", "onboarding-try", "onboarding-graded", "onboarding-promise", "onboarding-graph",
                                      "onboarding-goal", "onboarding-to-goal", "onboarding-account", "onboarding-heart",
                                      "onboarding-promised", "onboarding-year", "onboarding-name", "onboarding-plan",
                                      "onboarding-setting", "onboarding-cards", "onboarding-reminder",
                                      "onboarding-struggles", "onboarding-talk", "onboarding-timer",
                                      "onboarding-progress", "onboarding-daily", "onboarding-consent"]

    /// Runs before the first frame so the root picks the right side (auth vs app).
    static func prepareDefaults() {
        guard let screen else { return }
        let d = UserDefaults.standard
        d.set(!authScreens.contains(screen), forKey: AuthModel.signedInKey)
        // App screens open past the AI consent; `ai-consent` and onboarding start without it.
        let consented = !authScreens.contains(screen) && screen != "ai-consent"
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
        case "onboarding-intro", "onboarding-try", "onboarding-graded", "onboarding-promise", "onboarding-graph",
             "onboarding-goal", "onboarding-to-goal", "onboarding", "focus-system",
             "onboarding-account", "onboarding-heart", "onboarding-promised",
             "onboarding-year", "onboarding-name", "onboarding-plan", "onboarding-setting",
             "onboarding-cards", "onboarding-reminder", "onboarding-struggles", "onboarding-talk",
             "onboarding-timer", "onboarding-progress", "onboarding-daily", "onboarding-consent": [.onboarding]
        default: []
        }
    }

    @MainActor static func apply(app: AppState, tab: inout Tab, expandedPatient: inout String?) {
        guard let screen else { return }
        switch screen {
        case "patients", "previous-tries", "previous-try": tab = .patients
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
        case "admit":
            // Generates a live patient (the AI model via local Supabase) and opens its door note.
            tab = .today
            Task { @MainActor in await app.admit(focus: FocusSelection()) }
        default:
            // Case screens open the newest generated patient (admit one first from Home).
            let path: [CaseStep]
            switch screen {
            case "interview", "interview-exam", "interview-findings", "voice-listen", "voice-patient", "voice-live", "examine", "workup": path = [.interview]
            case "diagnosis", "diagnosis-suggest", "diagnosis-ddx", "diagnosis-ddx-add": path = [.interview, .diagnosis]
            case "handoff": path = [.interview, .diagnosis, .handoff]
            case "debrief", "debrief-graded": path = [.interview, .diagnosis, .handoff, .debrief]
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
