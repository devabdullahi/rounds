import SwiftUI

struct SignUpView: View {
    @Environment(AuthRouter.self) private var router

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    private var rules: [(String, Bool)] {
        [("8+ characters", password.count >= 8),
         ("A number", password.contains(where: \.isNumber)),
         ("A symbol", password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }))]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(glyph: .chevronLeft, label: "Back to welcome", quiet: true) { router.back() }
                Spacer()
            }
            .padding(.leading, 7)   // chevron edge on the 24pt auth margin

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start your first shift")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.5)
                        Text("Free daily patient. No card needed.")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 8)

                    // One tap with Apple or Google skips the form. "Continue": the provider decides
                    // whether the account is new, so the same words serve sign up, log in and the
                    // welcome sheet (and Apple allows only Sign in / Sign up / Continue with Apple).
                    VStack(spacing: 12) {
                        SocialButton(provider: .apple, title: "Continue with Apple") { router.go(.focus) }
                        SocialButton(provider: .google, title: "Continue with Google") { router.go(.focus) }
                    }
                    .padding(.top, 28)

                    OrDivider(text: "or with email")
                        .padding(.top, 20)

                    VStack(spacing: 12) {
                        AuthField(label: "Name", text: $name, placeholder: "What should Dr. Okafor call you?", contentType: .name)
                        AuthField(label: "Email", text: $email, placeholder: "you@school.edu",
                                  contentType: .emailAddress, keyboard: .emailAddress)
                        VStack(alignment: .leading, spacing: 8) {
                            // The rules up front, so nobody learns them by failing.
                            AuthField(label: "Password", text: $password, placeholder: "8+ characters, a number, a symbol",
                                      secure: true, contentType: .newPassword)
                            if !password.isEmpty {
                                strengthMeter.transition(.opacity.combined(with: .offset(y: -4)))
                            }
                        }
                    }
                    .padding(.top, 20)

                    // Right where the form ends, as on Log in; no gap between the last field and the action.
                    Button("Create account") { router.go(.focus) }
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                        .padding(.top, 22)
                    legal
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .animation(.easeOut(duration: 0.2), value: password.isEmpty)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text("Already have an account?").foregroundStyle(Theme.muted)
                    Button("Log in") { router.path = [.signIn] }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
                .font(.system(size: 15))
                .frame(minHeight: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var strengthMeter: some View {
        let met = rules.filter(\.1).count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<rules.count, id: \.self) { i in
                    Capsule()
                        .fill(i < met ? Theme.accent : Theme.text.opacity(0.10))
                        .frame(height: 4)
                }
            }
            .animation(Springs.pop, value: met)
            HStack(spacing: 14) {
                ForEach(rules, id: \.0) { rule, ok in
                    HStack(spacing: 4) {
                        AppIcon(ok ? .check : .circle, size: 13)
                        Text(rule)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(ok ? Theme.good : Theme.muted)
                    .animation(.easeOut(duration: 0.15), value: ok)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var legal: some View {
        Text("By continuing you agree to the [Terms](rounds://terms) and [Privacy Policy](rounds://privacy). Rounds is for practice and isn't medical advice.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .tint(Theme.accent)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .environment(\.openURL, OpenURLAction { _ in .handled })   // placeholders until the pages exist
    }
}
