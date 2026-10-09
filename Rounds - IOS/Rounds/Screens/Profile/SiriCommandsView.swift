import SwiftUI

/// Every way to use Rounds through Siri and Shortcuts: the phrases per action, the topics Siri
/// knows, and how to automate a daily patient.
struct SiriCommandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tip

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Commands")
                        VStack(spacing: 0) {
                            ForEach(Array(SiriCommand.direct.enumerated()), id: \.element.id) { i, command in
                                if i > 0 { Hairline() }
                                commandRow(command)
                            }
                        }
                        .listSurface()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Topics you can name")
                        Text(SiriCommand.topicNames.joined(separator: " · "))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listSurface()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Automate it")
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Have a patient waiting every day at 6 PM:")
                                .font(.system(size: 16, weight: .semibold))
                            ForEach(Array(SiriCommand.automationSteps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(i + 1)").font(.mono(14, weight: .medium)).foregroundStyle(Theme.accentText)
                                    Text(step).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Button("Open Shortcuts") {
                                if let url = URL(string: "shortcuts://") { openURL(url) }
                            }
                            .buttonStyle(PrimaryButtonStyle(height: 48))
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .listSurface()
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Siri commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Theme.accent)
    }

    /// The one rule that trips people up.
    private var tip: some View {
        HStack(alignment: .top, spacing: 12) {
            AppIcon(.mic, size: 18)
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text("Start with \"Hey Siri\" and say \"Rounds\" in the command, so Siri knows it's for this app.")
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listSurface()
    }

    private func commandRow(_ command: SiriCommand) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(command.title).font(.system(size: 16, weight: .semibold))
            Text(command.detail).font(.system(size: 14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(command.phrases, id: \.self) { phrase in
                    Text("“Hey Siri, \(phrase.prefix(1).lowercased() + phrase.dropFirst())”")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accentText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
