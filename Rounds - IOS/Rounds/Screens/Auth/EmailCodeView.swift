import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Enter code
 *
 *  appear   keyboard up on the hidden code field; Mail's code autofills from the bar
 *  typing   each box fills; the next box takes the green focus ring
 *  6 digits verifies on its own (the field locks while it checks)
 *  wrong    boxes turn red and shake once (360ms), digits clear, keyboard stays up,
 *           message appears under the boxes and is announced to VoiceOver;
 *           the action becomes "Send a new code" once the resend wait is over
 *
 * Reduce Motion: no shake; the red boxes and message still show.
 * ───────────────────────────────────────────────────────── */

private enum SHAKE {
    static let distance: CGFloat = 10
    static let step = 0.072   // five steps, 360ms
}

/// The code step for email log in and sign up (Rounds has no passwords). Where the student goes
/// next is decided by the account (`AuthRouter.enter`), not by which form sent them here.
struct EmailCodeView: View {
    let email: String

    @Environment(AuthRouter.self) private var router
    @Environment(AuthModel.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var code = ""
    @State private var shakes = 0
    @FocusState private var typing: Bool

    private var checking: Bool { auth.busy == .email }
    private var rejected: Bool { auth.codeProblem != nil && code.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(glyph: .chevronLeft, label: "Back", quiet: true) { router.back() }
                Spacer()
            }
            .padding(.leading, 21)   // circle edge on the 24pt auth margin (3pt inset in the hit box)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    boxes.padding(.top, 28)
                    status.padding(.top, 16)
                    TimelineView(.periodic(from: auth.codeSentAt ?? .now, by: 1)) { context in
                        actions(wait: auth.resendWait(now: context.date))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.never)

            HStack(spacing: 4) {
                Text("Wrong address?").foregroundStyle(Theme.muted)
                Button { router.back() } label: {
                    Text("Change email").fontWeight(.semibold).foregroundStyle(Theme.accentText)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: auth.codeProblem)
        .onAppear { typing = true }
        .onDisappear { auth.clearCodeProblem() }
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "email-code-error" { auth.debugRejectCode() } }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppIcon(.mail, size: 28)
                .foregroundStyle(Theme.accent)
                .frame(width: 56, height: 56)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 12)
                .accessibilityHidden(true)
            Text("Check your email")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            (Text("Enter the \(EmailCode.length)-digit code we sent to ") + Text(email).foregroundStyle(Theme.text).fontWeight(.semibold))
                .font(.system(size: 17))
                .foregroundStyle(Theme.muted)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let problem = auth.codeProblem {
            HStack(alignment: .top, spacing: 8) {
                AppIcon(.triangleAlert, size: 18)
                Text(problem)
            }
            .font(.system(size: 15))
            .foregroundStyle(Theme.warnText)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AppIcon(.clock, size: 16)
                    Text("The code works for \(EmailCode.validMinutes) minutes.")
                }
                // Codes come from a Gmail address through Amazon SES until Rounds has its own domain,
                // so some inboxes file them as spam.
                HStack(spacing: 8) {
                    AppIcon(.mail, size: 16)
                    Text("Not in your inbox? Check spam or junk.")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
        }
    }

    /// Verify (or, after a wrong code, send a new one) and the resend line. Both respect the same
    /// wait, so no path sends codes faster than the server allows.
    private func actions(wait: Int) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { rejected ? await resend() : await verify() }
            } label: {
                HStack(spacing: 8) {
                    if checking { ProgressView().tint(Theme.accentInk) }
                    Text(rejected ? (wait > 0 ? "New code in \(EmailCode.clock(wait))" : "Send a new code") : "Verify")
                        .monospacedDigit()
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
            .disabled(auth.busy != nil || (rejected ? wait > 0 : !EmailCode.isComplete(code)))
            .padding(.top, 24)

            HStack(spacing: 4) {
                Text("Didn\u{2019}t get it?").foregroundStyle(Theme.muted)
                Button { Task { await resend() } } label: {
                    Text(wait > 0 ? "Resend in \(EmailCode.clock(wait))" : "Resend code")
                        .fontWeight(.semibold)
                        .foregroundStyle(wait > 0 ? Theme.muted : Theme.accentText)
                        .monospacedDigit()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(wait > 0 || auth.busy != nil)
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity)
        }
    }

    /// Six boxes drawn over one hidden field, so iOS's one-time-code autofill and paste just work.
    private var boxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($typing)
                .disabled(checking)   // a code typed mid-check would be dropped, then wiped
                .opacity(0.02)        // invisible but still focusable and autofillable
                .onChange(of: code) { _, typed in
                    let clean = EmailCode.clean(typed)
                    if clean != typed { code = clean; return }
                    if !clean.isEmpty { auth.clearCodeProblem() }
                    if EmailCode.isComplete(clean) { Task { await verify() } }
                }
                .accessibilityLabel("Verification code")
                .accessibilityValue(code.isEmpty ? "Empty" : code.map(String.init).joined(separator: " "))

            HStack(spacing: 8) {
                ForEach(0..<EmailCode.length, id: \.self) { i in box(i) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { typing = true }
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: shakes) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-SHAKE.distance, duration: SHAKE.step)
                LinearKeyframe(SHAKE.distance, duration: SHAKE.step)
                LinearKeyframe(-SHAKE.distance * 0.6, duration: SHAKE.step)
                LinearKeyframe(SHAKE.distance * 0.6, duration: SHAKE.step)
                LinearKeyframe(0, duration: SHAKE.step)
            }
        }
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(code)
        let active = typing && !checking && i == min(code.count, EmailCode.length - 1) && code.count < EmailCode.length
        let wrong = auth.codeProblem != nil
        let stroke: Color = wrong ? Theme.wrong : active ? Theme.accent : Theme.control
        return Text(i < chars.count ? String(chars[i]) : "")
            .font(.system(size: 26, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(stroke, lineWidth: active || wrong ? 1.5 : 1))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.accent.opacity(active ? 0.16 : 0), lineWidth: 4).padding(-2))
            .animation(.easeOut(duration: 0.15), value: active)
    }

    private func verify() async {
        let submitted = code
        let account = await auth.verifyCode(email: email, code: submitted)
        // Left this screen while it checked (Back / Change email): stay where they went.
        guard router.path.last == .code(email: email) else { return }
        guard let account else {
            if let problem = auth.codeProblem, code == submitted {
                code = ""
                if !reduceMotion { shakes += 1 }
                typing = true
                AccessibilityNotification.Announcement(problem).post()
            }
            return
        }
        router.enter(account, auth: auth)
    }

    private func resend() async {
        code = ""
        _ = await auth.sendCode(email: email)
        typing = true
    }
}
