import SwiftUI

/// A small round account button that opens a menu with "Sign out" and "Delete account". Sits over
/// screens that otherwise have no way out, like the paywall, so a student without a plan can still
/// leave or delete their account (App Review 5.1.1(v)). The caller confirms the deletion.
struct AccountMenuButton: View {
    let signOut: () -> Void
    let deleteAccount: () -> Void
    var disabled = false

    var body: some View {
        Menu {
            Button("Sign out", action: signOut)
            Button("Delete account", role: .destructive, action: deleteAccount)
        } label: {
            AppIcon(.user, size: 18)
                .foregroundStyle(Theme.text)
                .frame(width: 38, height: 38)
                // Non-interactive glass: a menu's press shouldn't swell or flare the button.
                .glassFill(Theme.text.opacity(0.10), in: Circle(), interactive: false)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(disabled)
        .accessibilityLabel("Account")
        .accessibilityHint("Sign out or delete your account")
    }
}
