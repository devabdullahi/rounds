import SwiftUI

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
