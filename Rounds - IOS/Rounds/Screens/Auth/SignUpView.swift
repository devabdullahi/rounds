import SwiftUI

struct SignUpView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(AuthModel.self) private var auth

    @State private var name = ""
    @State private var email = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(glyph: .chevronLeft, label: "Back to welcome", quiet: true) { router.back() }
                Spacer()
            }
            .padding(.leading, 21)   // circle edge on the 24pt auth margin (3pt inset in the hit box)

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
                        SocialButton(provider: .apple, title: "Continue with Apple") { Task { await social(.apple) } }
                        SocialButton(provider: .google, title: "Continue with Google") { Task { await social(.google) } }
                    }
                    .padding(.top, 28)

                    OrDivider(text: "or with email")
                        .padding(.top, 20)

                    VStack(spacing: 12) {
                        AuthField(label: "Name", text: $name, placeholder: "What should Dr. Okafor call you?", contentType: .name)
                        AuthField(label: "Email", text: $email, placeholder: "you@school.edu",
                                  contentType: .emailAddress, keyboard: .emailAddress)
                    }
                    .padding(.top, 20)
                    // No passwords: the emailed code confirms the address and signs them in at once.
                    AuthNote(text: "We\u{2019}ll email you a \(EmailCode.length)-digit code to confirm it\u{2019}s you.")
                        .padding(.top, 10)

                    // Right where the form ends, as on Log in; no gap between the last field and the action.
                    Button {
                        Task {
                            if let address = await auth.sendCode(email: email, name: name) { router.go(.code(email: address)) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if auth.busy == .email { ProgressView().tint(.white) }
                            Text("Send code")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .disabled(!canCreate || auth.busy != nil)
                    .padding(.top, 22)
                    legal
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
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

    /// A name and an email shaped like an address.
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && EmailAddress.looksValid(email)
    }

    /// A brand-new account goes through onboarding; an existing one goes straight in.
    private func social(_ provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        router.enter(account, auth: auth)
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
