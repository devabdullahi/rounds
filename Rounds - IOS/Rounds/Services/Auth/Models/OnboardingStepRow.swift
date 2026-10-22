import Foundation

/// `public.onboarding_steps` as the app writes it: one onboarding page this install reached
/// (insert only; the app can't read it back).
struct OnboardingStepRow: Encodable {
    let install_id: UUID
    let page: String
    let step: Int
    let app_version: String
}
