import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Log in (email)
 *
 * Pushed from the welcome sheet's "Log in". Apple and Google sign in here
 * too, above the email form.
 *
 *    0ms   ECG mark draws (900ms, ease in-out)
 *  250ms   "Log in" rises, y 12 → 0
 *  330ms   subtitle rises
 *  450ms   Continue with Apple rises
 *  510ms   Continue with Google rises
 *  570ms   "or with email" divider fades in
 *  630ms   email field rises
 *  690ms   "we'll email you a code" note fades in
 *  750ms   Send code button rises
 *  880ms   footer link fades in
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
    static let divider  = 0.57
    static let email    = 0.63
    static let note     = 0.69
    static let submit   = 0.75
    static let footer   = 0.88
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
    @Environment(AuthModel.self) private var auth

    @State private var email = ""
    @State private var drawn: CGFloat = 0
    @State private var shown = false
    @State private var appearedAt = Date.now

    /// A first Apple or Google sign-in still goes through onboarding; a returning one goes in.
    private func social(_ provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        router.enter(account, auth: auth)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(glyph: .chevronLeft, label: "Back to welcome", quiet: true) { router.back() }
                Spacer()
            }
            .padding(.leading, 21)   // circle edge on the 24pt auth margin (3pt inset in the hit box)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    mark
                    Text("Log in")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .rise(shown, at: TIMING.title)
                    Text("Your patients are waiting.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.muted)
                        .rise(shown, at: TIMING.subtitle)
                }

                // "Continue", as on sign up and the welcome sheet: the provider knows whether the
                // account exists (Apple allows only Sign in / Sign up / Continue with Apple).
                VStack(spacing: 12) {
                    SocialButton(provider: .apple, title: "Continue with Apple") { Task { await social(.apple) } }
                        .rise(shown, at: TIMING.apple)
                    SocialButton(provider: .google, title: "Continue with Google") { Task { await social(.google) } }
                        .rise(shown, at: TIMING.google)
                }
                .padding(.top, 28)

                OrDivider(text: "or with email")
                    .padding(.top, 20)
                    .rise(shown, at: TIMING.divider, fadeOnly: true)

                // No passwords: a 6-digit code goes to this address (EmailCodeView takes it from there).
                AuthField(label: "Email", text: $email, placeholder: "you@school.edu",
                          contentType: .emailAddress, keyboard: .emailAddress)
                    .rise(shown, at: TIMING.email)
                    .padding(.top, 20)
                AuthNote(text: "We\u{2019}ll email you a \(EmailCode.length)-digit code. No password needed.")
                    .padding(.top, 10)
                    .rise(shown, at: TIMING.note, fadeOnly: true)

                Button {
                    Task {
                        if let address = await auth.sendCode(email: email) { router.go(.code(email: address)) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.busy == .email { ProgressView().tint(.white) }
                        Text("Send code")
                    }
                }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .disabled(!EmailAddress.looksValid(email) || auth.busy != nil)
                    .padding(.top, 22)
                    .rise(shown, at: TIMING.submit)

                Spacer(minLength: 40)

                HStack(spacing: 4) {
                    Text("New to Rounds?").foregroundStyle(Theme.muted)
                    Button("Create an account") { router.path = [.signUp] }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .rise(shown, at: TIMING.footer, fadeOnly: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(minHeight: UIScreen.main.bounds.height - 170, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        }
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
