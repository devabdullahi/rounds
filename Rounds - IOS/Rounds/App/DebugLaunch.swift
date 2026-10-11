#if DEBUG
import SwiftUI

/// Dev-only deep link for screenshots: launch with `-screen <name>`.
/// Names: firstopen, firstopen-auth, signin, signup, onboarding (focus), onboarding-intro, onboarding-graded,
/// onboarding-promise, onboarding-graph, onboarding-goal, onboarding-to-goal, onboarding-heart, onboarding-promised, email-code,
/// email-code-error, focus-system, focus-sheet, home, patients, patients-open, profile, brief, interview, examine, workup, diagnosis, debrief, diagnosis-suggest.
enum DebugLaunch {
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }

    /// `-hr 130` previews the Home monitor at another heart rate.
    static var heartRate: Int? {
        let v = UserDefaults.standard.integer(forKey: "hr")
        return v > 0 ? v : nil
    }

    private static let authScreens = ["firstopen", "firstopen-auth", "signin", "signup", "onboarding", "focus-system", "google-signin",
                                      "onboarding-intro", "onboarding-graded", "onboarding-promise", "onboarding-graph",
                                      "onboarding-goal", "onboarding-to-goal", "onboarding-heart", "onboarding-promised",
                                      "email-code", "email-code-error"]

    /// Runs before the first frame so the root picks the right side (auth vs app).
    static func prepareDefaults() {
        guard let screen else { return }
        let d = UserDefaults.standard
        d.set(!authScreens.contains(screen), forKey: AuthModel.signedInKey)
        if ["onboarding-heart", "onboarding-promised", "paywall"].contains(screen) {
            d.set(StudyGoal.step2CK.rawValue, forKey: StudyGoal.storageKey)
            d.set(StudyFocus.rotation(.internalMedicine).stored, forKey: StudyFocus.storageKey)
        }
        if ["focus-sheet", "home", "settings", "settings-siri", "settings-voice", "settings-subscription"].contains(screen) {
            d.set(StudyFocus.rotation(.internalMedicine).stored, forKey: StudyFocus.storageKey)
        }
    }

    /// Fictional signed-in student for screenshots of account screens.
    static let sampleAccount = Account(id: "debug", email: "maya.patel@school.edu", name: "Maya Patel",
                                       provider: "google", createdAt: .now,
                                       specialty: .emergencyMedicine, onboarded: true)

    static var authPath: [AuthStep] {
        switch screen {
        case "signin", "google-signin": [.signIn]
        case "signup": [.signUp]
        case "email-code", "email-code-error": [.signIn, .code(email: "maya@school.edu")]
        case "onboarding-intro", "onboarding-graded", "onboarding-promise", "onboarding-graph",
             "onboarding-goal", "onboarding-to-goal", "onboarding", "focus-system",
             "onboarding-heart", "onboarding-promised": [.signUp, .onboarding]
        default: []
        }
    }

    @MainActor static func apply(app: AppState, tab: inout Tab, expandedPatient: inout String?) {
        guard let screen else { return }
        switch screen {
        case "patients": tab = .patients
        case "cards", "cards-flip", "cards-correct", "cards-unknown", "cards-new", "cards-new-color", "cards-new-answer",
             "cards-add", "cards-generate", "cards-generate-notes", "cards-generate-notes-pick", "cards-generate-mistakes": tab = .cards
        case "patients-open": tab = .patients; expandedPatient = "R2"
        case "profile", "settings", "settings-siri", "settings-voice", "settings-subscription", "profile-weakspots", "profile-badges", "profile-edit": tab = .profile
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
            // Generates a live patient (DeepSeek via local Supabase) and opens its door note.
            tab = .today
            Task { @MainActor in await app.admit(focus: FocusSelection()) }
        default:
            // Case screens open the newest generated patient (admit one first from Home).
            let path: [CaseStep]
            switch screen {
            case "interview", "demo-interview", "interview-exam", "interview-chat", "interview-exam-chat", "interview-findings", "voice-listen", "voice-patient", "examine": path = [.interview]
            case "workup": path = [.interview, .workup]
            case "diagnosis", "diagnosis-suggest", "diagnosis-ddx", "diagnosis-ddx-add": path = [.interview, .workup, .diagnosis]
            case "handoff": path = [.interview, .workup, .diagnosis, .handoff]
            case "debrief", "debrief-graded": path = [.interview, .workup, .diagnosis, .handoff, .debrief]
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

// MOCK (disabled): seeded the scripted chest-pain conversation for screenshots.
// extension CaseSession {
//     func debugSeed(through step: CaseStep) {
//         debugInject(
//             messages: [
//                 ChatMessage(kind: .doctor, text: "Can you show me where the pain is? Does it go anywhere else?"),
//                 ChatMessage(kind: .patient, text: clinical.facts[1].reply),
//                 ChatMessage(kind: .reveal, text: "Revealed: radiation, site"),
//                 ChatMessage(kind: .doctor, text: "Do you smoke, or have any heart problems in the family?"),
//                 ChatMessage(kind: .patient, text: clinical.facts[5].reply),
//                 ChatMessage(kind: .reveal, text: "Revealed: smoking, family history"),
//             ],
//             revealed: ["site", "risk", "onset", "character"],
//             examined: step == .interview ? [] : ["inspect", "heart"],
//             tests: step == .interview ? [] : ["ecg", "trop"],
//             pending: step == .workup ? ["trop"] : []
//         )
//         if step == .diagnosis {
//             diagnosis = "Inferior STEMI"
//             plan = "Aspirin, activate cath lab for primary PCI, oxygen only if sats drop below 94%, analgesia."
//         }
//     }
// }
#endif
