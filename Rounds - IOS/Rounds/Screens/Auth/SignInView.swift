import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Sign in
 *
 * Picks up from First open: the ECG mark redraws, then monitors.
 *
 *    0ms   ECG mark draws (900ms, ease in-out)
 *  250ms   "Welcome back" rises, y 12 → 0
 *  330ms   subtitle rises
 *  450ms   Apple button rises
 *  510ms   Google button rises
 *  600ms   "or use email" divider fades in
 *  660ms   email field rises
 *  720ms   password field rises
 *  780ms   Sign in button rises
 *  900ms   footer link fades in
 * 1200ms   bright pulse sweeps the mark, every 2.4s, forever
 *
 * 60ms stagger, ~0.9s total; nothing blocks taps.
 * Fields glow mint on focus; buttons press down.
 * Reduce Motion: no sweep, no rise.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let title    = 0.25
    static let subtitle = 0.33
    static let apple    = 0.45
    static let google   = 0.51
    static let divider  = 0.60
    static let email    = 0.66
    static let password = 0.72
    static let submit   = 0.78
    static let footer   = 0.90
}

private enum MARK {
    static let size = CGSize(width: 120, height: 32)
    static let drawCurve = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)
}

private enum SWEEP {
    static let start = 1.2        // s after appear
    static let period = 2.4       // s per pass
    static let length: CGFloat = 0.1   // fraction of the trace lit at once
    static let color = Theme.sweep
    static let lineWidth: CGFloat = 2.4
}

struct SignInView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("signedIn") private var signedIn = false

    @State private var email = ""
    @State private var password = ""
    @State private var drawn: CGFloat = 0
    @State private var shown = false
    @State private var appearedAt = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    mark
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .rise(shown, at: TIMING.title)
                    Text("Your patients are waiting.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.muted)
                        .rise(shown, at: TIMING.subtitle)
                }

                VStack(spacing: 12) {
                    SocialButton(provider: .apple, title: "Sign in with Apple") { signedIn = true }
                        .rise(shown, at: TIMING.apple)
                    SocialButton(provider: .google, title: "Continue with Google") { signedIn = true }
                        .rise(shown, at: TIMING.google)
                }
                .padding(.top, 36)

                OrDivider(text: "or use email")
                    .padding(.vertical, 24)
                    .rise(shown, at: TIMING.divider, fadeOnly: true)

                VStack(spacing: 14) {
                    AuthField(label: "Email", text: $email, placeholder: "you@school.edu",
                              contentType: .emailAddress, keyboard: .emailAddress)
                        .rise(shown, at: TIMING.email)
                    AuthField(label: "Password", text: $password, secure: true, contentType: .password,
                              accessoryTitle: "Forgot password?")
                        .rise(shown, at: TIMING.password)
                }

                Button("Sign in") { signedIn = true }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .padding(.top, 22)
                    .rise(shown, at: TIMING.submit)

                Spacer(minLength: 40)

                HStack(spacing: 4) {
                    Text("New to Rounds?").foregroundStyle(Theme.muted)
                    Button("Create an account") { router.go(.signUp) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .rise(shown, at: TIMING.footer, fadeOnly: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .frame(minHeight: UIScreen.main.bounds.height - 120, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        #if DEBUG
        .devSkip()
        #endif
        .onAppear(perform: play)
    }

    private var mark: some View {
        ZStack(alignment: .leading) {
            ECGMarks.compact
                .trim(from: 0, to: drawn)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .shadow(color: Theme.accent.opacity(0.6), radius: 4)

            if !reduceMotion {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSince(appearedAt) - SWEEP.start
                    let x = t < 0 ? -1 : CGFloat(t.truncatingRemainder(dividingBy: SWEEP.period) / SWEEP.period) * (1 + SWEEP.length)
                    ECGMarks.compact
                        .trim(from: max(0, x - SWEEP.length), to: min(1, max(0, x)))
                        .stroke(SWEEP.color, style: StrokeStyle(lineWidth: SWEEP.lineWidth, lineCap: .round, lineJoin: .round))
                        .shadow(color: Theme.accent, radius: 6)
                        .opacity(x > 0 && x < 1 + SWEEP.length ? 1 : 0)
                }
            }
        }
        .frame(width: MARK.size.width, height: MARK.size.height)
        .accessibilityHidden(true)
    }

    private func play() {
        appearedAt = .now
        guard !reduceMotion else { drawn = 1; shown = true; return }
        drawn = 0
        withAnimation(MARK.drawCurve) { drawn = 1 }
        shown = true
    }
}
