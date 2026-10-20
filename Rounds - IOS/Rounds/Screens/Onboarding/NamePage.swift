import SwiftUI

/// "What should we call you?": a first-name field. The keyboard opens while the page is in view;
/// Return moves on once a name is typed.
struct NamePage: View {
    /// Whether this page is the one in view: the keyboard is up only then.
    let active: Bool
    let onSubmit: () -> Void
    @AppStorage(ProfileName.storageKey) private var stored = ""
    @FocusState private var typing: Bool

    var body: some View {
        OnboardingQuestion(title: "What should we call you?") {
            VStack(alignment: .leading, spacing: 8) {
                Text("First name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                TextField("", text: $stored, prompt: Text("First name").foregroundStyle(Theme.faint))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($typing)
                    .onSubmit { if ProfileName.clean(stored) != nil { onSubmit() } }
                    .onChange(of: stored) { _, new in
                        if new.count > ProfileName.maxLength { stored = String(new.prefix(ProfileName.maxLength)) }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 60)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(typing ? Theme.accent : Theme.text.opacity(0.12), lineWidth: typing ? 1.5 : 1)
                    )
                    .accessibilityLabel("First name")
            }
        }
        // Keyboard up on arrival, down on leaving, so it never covers another page.
        .onChange(of: active, initial: true) { _, now in typing = now }
    }
}
