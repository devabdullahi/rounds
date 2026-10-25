import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Welcome (hillside)
 *
 * Every signed-out launch. Light mode. Two states: welcome, then the log-in sheet.
 *
 *    0ms   the hillside scene plays its intro (HillsideScene has its own storyboard)
 * 1300ms   headline rises, y 12 → 0
 * 1500ms   "Get Started" rises, "I have an account" with it
 *
 * "I have an account" tapped: headline + buttons fade; sheet (Apple, Google) springs up over a scrim.
 * "Get Started" tapped: onboarding pushes in; the account is made near its end.
 * Tap the scrim or drag the sheet's handle down: back to welcome.
 * Reduce Motion: the scene's final frame, still.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let headline = 1.30   // headline rises once the scene has landed
    static let cta      = 1.50   // "Get Started" rises
}

private enum SHEET {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let dismissDrag: CGFloat = 90
}

/// The signed-out welcome: a new student taps "Get Started" and makes their account during
/// onboarding; a returning one taps "I have an account" and logs in with Apple or Google.
struct FirstOpenView: View {
    /// The provider whose sheet is open; both buttons wait while it is.
    var signingInWith: SocialProvider?
    var onFirstTime: () -> Void
    var onSocial: (SocialProvider) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var showAuth = false
    @State private var sheetDrag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            welcome

            if showAuth {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                    .zIndex(1)
                authSheet
                    .offset(y: max(0, sheetDrag))
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        #if DEBUG
        .devSkip()
        .onAppear { if DebugLaunch.screen == "firstopen-auth" { showAuth = true } }
        #endif
        .onAppear { shown = true }
    }

    // MARK: Welcome

    private var welcome: some View {
        ZStack {
            HillsideScene()
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    AppIcon(.brandMark, size: 36).foregroundStyle(Theme.Hillside.roof)
                    Text("Interview patients.\nFind the diagnosis.")
                        .font(.system(size: 32, weight: .heavy))
                        .tracking(-0.6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Hillside.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .rise(shown && !showAuth, at: showAuth ? 0 : TIMING.headline)

                Spacer(minLength: 0)

                // New students are the ones to win over, so starting is the big button.
                VStack(spacing: 6) {
                    Button("Get Started", action: onFirstTime)
                        .buttonStyle(PrimaryButtonStyle(height: 54, tint: Theme.welcomeGreen))

                    Button { open() } label: {
                        HStack(spacing: 6) {
                            Text("I have an account")
                            AppIcon(.arrowRight, size: 16)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accentInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressDownStyle())
                    .accessibilityLabel("I have an account. Log in")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .rise(shown && !showAuth, at: showAuth ? 0 : TIMING.cta)
                .allowsHitTesting(!showAuth)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Sheet

    private var authSheet: some View {
        VStack(spacing: 12) {
            // Handle strip: the only drag target, so it never competes with the buttons.
            Capsule().fill(Theme.text.opacity(0.15)).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
                .gesture(dragToClose)

            ProviderButtons(busy: signingInWith, onSelect: onSocial)

            SignUpTermsNote()
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.10), radius: 30, y: -10)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var dragToClose: some Gesture {
        DragGesture()
            .onChanged { sheetDrag = $0.translation.height }
            .onEnded { value in
                if value.translation.height > SHEET.dismissDrag || value.predictedEndTranslation.height > SHEET.dismissDrag * 2 {
                    close()
                } else {
                    withAnimation(SHEET.spring) { sheetDrag = 0 }
                }
            }
    }

    // MARK: Choreography

    private func open() {
        withAnimation(SHEET.spring) { showAuth = true }
    }

    private func close() {
        withAnimation(SHEET.spring) {
            showAuth = false
            sheetDrag = 0
        }
    }
}
