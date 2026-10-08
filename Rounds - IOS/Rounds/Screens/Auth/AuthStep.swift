import SwiftUI
import Observation

/// Signed-out steps. Email sign-up and log in go through `code`; an account that hasn't finished
/// onboarding then runs intro → studyGoal → focus → promise before entering the app.
enum AuthStep: Hashable {
    case signIn, signUp, onboarding
    case code(email: String)
}
