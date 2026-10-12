import SwiftUI
import Observation

/// Signed-out steps past the welcome screen. Signing in is Apple or Google from the welcome sheet;
/// onboarding (intro → study goal → focus → account → promise) is the one pushed step.
enum AuthStep: Hashable {
    case onboarding
}
