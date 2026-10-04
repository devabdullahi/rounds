#if DEBUG
import SwiftUI

/// Dev-only deep link for screenshots: launch with `-screen <name>`.
/// Names: firstopen, firstopen-auth, signin, signup, onboarding, focus-rotation, focus-system, focus-sheet, home, patients, patients-open, profile, brief, interview, examine, workup, diagnosis, debrief.
enum DebugLaunch {
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }

    /// `-hr 130` previews the Home monitor at another heart rate.
    static var heartRate: Int? {
        let v = UserDefaults.standard.integer(forKey: "hr")
        return v > 0 ? v : nil
    }

    private static let authScreens = ["firstopen", "firstopen-auth", "signin", "signup", "onboarding", "focus-rotation", "focus-system"]

    /// Runs before the first frame so the root picks the right side (auth vs app).
    static func prepareDefaults() {
        guard let screen else { return }
        let d = UserDefaults.standard
        d.set(!authScreens.contains(screen), forKey: "signedIn")
        switch screen {
        case "focus-system": d.set(TrainingLevel.ms12.rawValue, forKey: TrainingLevel.storageKey)
        case "focus-rotation", "focus-sheet", "home", "settings":
            d.set(TrainingLevel.ms3.rawValue, forKey: TrainingLevel.storageKey)
            d.set(StudyFocus.rotation(.internalMedicine).stored, forKey: StudyFocus.storageKey)
        default: break
        }
    }

    static var authPath: [AuthStep] {
        switch screen {
        case "signin": [.signIn]
        case "signup": [.signUp]
        case "onboarding": [.signUp, .onboarding]
        case "focus-rotation", "focus-system": [.signUp, .onboarding, .focus]
        default: []
        }
    }

    static func apply(app: AppState, tab: inout Tab, expandedPatient: inout String?) {
        guard let screen else { return }
        switch screen {
        case "patients": tab = .patients
        case "cards", "cards-flip", "cards-correct", "cards-unknown", "cards-new", "cards-new-color", "cards-new-answer": tab = .cards
        case "patients-open": tab = .patients; expandedPatient = "R2"
        case "profile", "settings": tab = .profile
        case "home", "focus-sheet", "splash", "home-swipe-right", "home-swipe-left": tab = .today
        default:
            let s = CaseSession()
            let path: [CaseStep]
            switch screen {
            case "interview", "voice-listen", "voice-patient": s.debugSeed(through: .interview); path = [.interview]
            case "examine": s.debugSeed(through: .interview); path = [.interview]
            case "workup": s.debugSeed(through: .workup); path = [.interview, .workup]
            case "diagnosis": s.debugSeed(through: .diagnosis); path = [.interview, .workup, .diagnosis]
            case "handoff": s.debugSeed(through: .diagnosis); path = [.interview, .workup, .diagnosis, .handoff]
            case "debrief": s.debugSeed(through: .diagnosis); path = [.interview, .workup, .diagnosis, .handoff, .debrief]
            default: path = []
            }
            app.debugInitialPath = path
            app.activeCase = s
        }
    }
}

extension CaseSession {
    func debugSeed(through step: CaseStep) {
        debugInject(
            messages: [
                ChatMessage(kind: .doctor, text: "Can you show me where the pain is? Does it go anywhere else?"),
                ChatMessage(kind: .patient, text: clinical.facts[1].reply),
                ChatMessage(kind: .reveal, text: "Revealed: radiation, site"),
                ChatMessage(kind: .doctor, text: "Do you smoke, or have any heart problems in the family?"),
                ChatMessage(kind: .patient, text: clinical.facts[5].reply),
                ChatMessage(kind: .reveal, text: "Revealed: smoking, family history"),
            ],
            revealed: ["site", "risk", "onset", "character"],
            examined: step == .interview ? [] : ["inspect", "heart"],
            tests: step == .interview ? [] : ["ecg", "trop"],
            pending: step == .workup ? ["trop"] : []
        )
        if step == .diagnosis {
            diagnosis = "Inferior STEMI"
            plan = "Aspirin, activate cath lab for primary PCI, oxygen only if sats drop below 94%, analgesia."
        }
    }
}
#endif
