import SwiftUI
import Observation

// MARK: - Flow

enum AuthStep: Hashable { case signIn, signUp, focus }

@Observable
final class AuthRouter {
    var path: [AuthStep] = []
    func go(_ step: AuthStep) { path.append(step) }
    func back() { if !path.isEmpty { path.removeLast() } }
}

/// Signed-out shell: welcome, sign up, log in and the focus question, over real accounts
/// (AuthModel). A new account goes through the focus question; a returning one goes straight in.
struct AuthFlowView: View {
    @Environment(AuthModel.self) private var auth
    @State private var router = AuthRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            // Everyone signed out lands on the welcome screen; its sheet branches to
            // sign up, email log in, or Apple/Google (straight to the year question).
            FirstOpenView(
                onSignUp: { router.go(.signUp) },
                onLogIn: { router.go(.signIn) },
                onSocial: { provider in Task { await continueWith(provider) } }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthStep.self) { step in
                Group {
                    switch step {
                    case .signIn: SignInView()
                    case .signUp: SignUpView()
                    case .focus: FocusOnboardingView()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .environment(router)
        .alert("Couldn't sign in", isPresented: Binding(get: { auth.problem != nil }, set: { if !$0 { auth.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.problem ?? "")
        }
        #if DEBUG
        .onAppear { router.path = DebugLaunch.authPath }
        #endif
    }

    /// Apple or Google: a new account answers the focus question first; a returning one goes in.
    private func continueWith(_ provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        if account.isNew() { router.go(.focus) } else { auth.finishSignIn() }
    }
}

// MARK: - ECG marks


enum ECGMarks {
    /// Wide trace used on First open (342×64).
    static let wide = SVGShape(d: "M0 38 h96 l6 -6 l6 6 h12 l4 5 l7 -40 l7 50 l5 -15 h16 l8 -8 l8 8 h167",
                               viewBox: CGSize(width: 342, height: 64))
    /// Compact mark used on Sign in (120×32).
    static let compact = SVGShape(d: "M0 20 h30 l4 -4 l4 4 h8 l3 3 l4 -22 l4 28 l3 -9 h10 l6 -5 l6 5 h38",
                                  viewBox: CGSize(width: 120, height: 32))
}

// MARK: - Fields

struct AuthField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var secure = false
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var accessoryTitle: String? = nil
    var accessoryAction: () -> Void = {}
    var forceHighlight = false

    @FocusState private var focused: Bool
    @State private var reveal = false

    private var lit: Bool { focused || forceHighlight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                if let accessoryTitle {
                    Button(accessoryTitle, action: accessoryAction)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            HStack(spacing: 0) {
                Group {
                    if secure && !reveal {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.faint))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.faint))
                    }
                }
                .font(.system(size: 17))
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress || secure ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || secure)
                .focused($focused)
                .accessibilityLabel(label)

                if secure {
                    Button { reveal.toggle() } label: {
                        AppIcon(reveal ? .eyeOff : .eye, size: 20)
                            .foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(reveal ? "Hide password" : "Show password")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, secure ? 4 : 16)
            .frame(height: 50)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(lit ? Theme.accent : Theme.border, lineWidth: lit ? 1.5 : 1)
            )
            // Mint focus glow: a soft 4pt halo outside the field.
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.accent.opacity(focused ? 0.16 : 0), lineWidth: 4)
                    .padding(-2)
            )
            .animation(.easeOut(duration: 0.18), value: focused)
        }
    }
}

// MARK: - Buttons


struct SocialButton: View {
    let provider: SocialProvider
    let title: String
    var height: CGFloat = 52
    let action: () -> Void

    private enum SOCIAL {
        static let icon: CGFloat = 20          // shared icon box so both marks read the same size
        static let iconInset: CGFloat = 20     // pinned icon's distance from the leading edge
        static let gap: CGFloat = 8            // icon ↔ label in compact buttons
    }

    /// Full-width buttons pin the icon to the leading edge and center the label, so stacked
    /// buttons share one icon column. Half-width buttons center icon + label together.
    private var pinsIcon: Bool { height >= 52 }

    var body: some View {
        Button(action: action) {
            ZStack {
                if pinsIcon {
                    HStack { icon; Spacer() }
                        .padding(.leading, SOCIAL.iconInset)
                    Text(title)
                } else {
                    HStack(spacing: SOCIAL.gap) { icon; Text(title) }
                }
            }
            .font(.system(size: pinsIcon ? 17 : 16, weight: .semibold))
            .foregroundStyle(provider == .apple ? Theme.bg : Theme.text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(provider == .apple ? Theme.text : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border)
                }
            }
        }
        .buttonStyle(PressDownStyle())
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            // Apple's mark is required on Sign in with Apple and only ships as an SF Symbol.
            // The glyph sits low and small in its box; nudge it to match the G optically.
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .medium))
                .offset(y: -1)
                .frame(width: SOCIAL.icon, height: SOCIAL.icon)
        case .google:
            GoogleLogo(size: SOCIAL.icon - 2)   // the G's round shape reads larger than the Apple mark
                .frame(width: SOCIAL.icon, height: SOCIAL.icon)
        }
    }
}

/// Buttons press down: scale 0.97 and dim slightly.
struct PressDownStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OrDivider: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize()
            Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1)
        }
    }
}

/// Staggered rise used across auth screens. Never blocks taps; Reduce Motion shows everything at once.
struct Rise: ViewModifier {
    let shown: Bool
    let delay: Double
    var offset: CGFloat = 12
    var fadeOnly = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || fadeOnly ? 0 : offset)
            .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: fadeOnly ? 0.4 : 0.45).delay(delay), value: shown)
    }
}

extension View {
    func rise(_ shown: Bool, at delay: Double, offset: CGFloat = 12, fadeOnly: Bool = false) -> some View {
        modifier(Rise(shown: shown, delay: delay, offset: offset, fadeOnly: fadeOnly))
    }
}

#if DEBUG
/// Dev shortcut past auth. Compiled out of release builds.
struct DevSkipButton: View {
    @AppStorage("signedIn") private var signedIn = false

    var body: some View {
        Button {
            signedIn = true
        } label: {
            HStack(spacing: 4) {
                Text("Skip")
                AppIcon(.chevronRight, size: 16)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Theme.track, in: Capsule())
        }
        .buttonStyle(PressDownStyle())
        .accessibilityLabel("Skip sign in")
    }
}

extension View {
    /// Pins the dev Skip button to the top-right corner.
    func devSkip() -> some View {
        overlay(alignment: .topTrailing) {
            DevSkipButton().padding(.trailing, 16).padding(.top, 4)
        }
    }
}
#endif
