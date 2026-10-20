import SwiftUI

/// "What should we call you?": a name card with a text field, the typed name shown big as the
/// student writes it. The keyboard opens when the page arrives; Return moves on.
struct NameHero: View {
    let shown: Bool
    /// Whether this page is the one in view: the keyboard is up only then.
    let active: Bool
    /// Runs when the student presses Return with a name typed.
    var onSubmit: () -> Void = {}
    @AppStorage(ProfileName.storageKey) private var stored = ""
    @FocusState private var typing: Bool

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(14, 40).heroPop(shown, delay: 0.1)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(318, 330).heroPop(shown, delay: 0.16)
        }
        .overlay {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 52, height: 52)
                        .background(Theme.heroMint, in: Circle())
                        .accessibilityHidden(true)
                    Text("Student doctor")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                TextField("First name", text: $stored)
                    .font(.system(size: 28, weight: .bold))
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
                    .accessibilityLabel("First name")
                Rectangle().fill(typing ? Theme.accent : Theme.hairline).frame(height: 2)
            }
            .padding(22)
            .frame(width: 320)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.text.opacity(0.10), radius: 24, y: 14)
            .heroPop(shown, delay: 0)
        }
        // Keyboard up on arrival, down on leaving, so it never covers another page.
        .onChange(of: active, initial: true) { _, now in typing = now }
    }

    /// Up to two initials from the typed name, or a placeholder dot pattern before anything's typed.
    private var initials: String {
        let letters = (ProfileName.clean(stored) ?? "").split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "·" : String(letters).uppercased()
    }
}
