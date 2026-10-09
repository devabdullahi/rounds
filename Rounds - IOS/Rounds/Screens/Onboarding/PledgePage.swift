import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Promise (hold the heart)
 *
 *  press   heart dips to 0.96; red rises from the tip (1.6s to full)
 *  25/50/75%  light haptic tick
 *  release before full (or the system cancels the touch)   red drains back down (0.4s)
 *  full    success haptic; heart springs to 1.06; headline → "Promise Made";
 *          hint swaps for Get Started; VoiceOver hears "Promise made"
 *
 * Reduce Motion: no dip or spring; the fill still tracks the hold.
 * VoiceOver: activating the heart makes the promise at once.
 * ───────────────────────────────────────────────────────── */

private enum HEART {
    static let pressedScale = 0.96
    static let doneScale = 1.06
    /// How often the fill is stepped; each step uses the real time elapsed, so a slow frame
    /// never stretches the 1.6s fill.
    static let tick = Duration.milliseconds(16)
}

/// Last onboarding page: the student promises to show up by holding the heart until it fills.
/// The carousel (`OnboardingView`) owns the heart's state, since its bottom control and back
/// button change once the promise is made.
struct PledgePage: View {
    @Binding var heart: HoldToCommit
    /// Mirrors the press, so the carousel's hint can say "Keep holding…".
    @Binding var isHolding: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""

    /// Resets by itself when the touch ends *or* the system cancels it (a call, Control Center),
    /// so the heart can never keep filling with no finger on it.
    @GestureState private var pressing = false
    private var holding: Bool { pressing && !heart.isDone }

    var body: some View {
        VStack(spacing: 14) {
            HeroCanvas {
                Ellipse().stroke(Theme.wrong.opacity(0.12)).frame(width: 320, height: 300).at(15, 50)
                Ellipse().stroke(Theme.wrong.opacity(0.10)).frame(width: 240, height: 220).at(55, 90)
                Sparkle().fill(Theme.surface).frame(width: 28, height: 28).at(24, 40)
                Sparkle().fill(Theme.surface).frame(width: 24, height: 40).at(300, 290)
                if let goal = StudyGoal(stored: goalStored) { HeroTag(text: goal.label).at(4, 270) }
                HeroTag(text: FocusSelection(stored: focusStored).label).at(196, 70)
            }
            .overlay { heartButton }
            .frame(maxHeight: 420)

            OnboardingHeadline(text: heart.isDone ? "Promise Made" : "I Promise to Show Up\nfor My Patients")
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: heart.isDone)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .haptic(.impact(weight: .light), trigger: heart.quarter) { old, new in new > old && new < 4 }
        .haptic(.success, trigger: heart.isDone) { _, done in done }
        .onChange(of: heart.isDone) { _, done in
            if done { AccessibilityNotification.Announcement("Promise made").post() }
        }
        .task(id: holding) { await run() }
        .onChange(of: holding) { _, now in isHolding = now }
    }

    private var heartButton: some View {
        HoldHeart(progress: heart.progress)
            .scaleEffect(reduceMotion ? 1 : heart.isDone ? HEART.doneScale : holding ? HEART.pressedScale : 1)
            .animation(reduceMotion ? nil : Springs.pop, value: holding)
            .animation(reduceMotion ? nil : Springs.pop, value: heart.isDone)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, pressing, _ in pressing = true }
            )
            .accessibilityElement()
            .accessibilityLabel("Promise heart")
            .accessibilityValue(heart.isDone ? "Promise made" : "")
            .accessibilityHint(heart.isDone ? "" : "Double-tap to promise to show up for your patients.")
            .accessibilityAddTraits(heart.isDone ? [] : .isButton)
            .accessibilityAction { if !heart.isDone { heart.complete() } }
    }

    /// Steps the fill while it's held or draining, by the time that really passed; stops once it
    /// settles or the hold changes (the task is replaced, and a cancelled one changes nothing).
    private func run() async {
        let clock = ContinuousClock()
        var last = clock.now
        while !heart.isSettled(holding: holding) {
            do { try await Task.sleep(for: HEART.tick) } catch { return }
            let now = clock.now
            let elapsed = last.duration(to: now)
            last = now
            heart.advance(by: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18,
                          holding: holding)
        }
    }
}
