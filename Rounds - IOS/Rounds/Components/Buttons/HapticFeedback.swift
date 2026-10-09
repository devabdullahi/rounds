import SwiftUI

/// `.sensoryFeedback` that stays quiet when the student turns Haptics off in Settings.
private struct HapticFeedback<Trigger: Equatable>: ViewModifier {
    @AppStorage(Preferences.hapticsKey) private var enabled = Preferences.hapticsDefault
    let feedback: SensoryFeedback
    let trigger: Trigger
    let condition: (Trigger, Trigger) -> Bool

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { [enabled, condition] old, new in
            enabled && condition(old, new)
        }
    }
}

extension View {
    /// Plays `feedback` when `trigger` changes (and `condition` holds), unless Haptics is off.
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T,
                              condition: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        modifier(HapticFeedback(feedback: feedback, trigger: trigger, condition: condition))
    }
}
