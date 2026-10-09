import SwiftUI

/// Credits the licences ask for: the badge artwork comes from game-icons.net under CC BY 3.0,
/// which requires naming each artist.
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Badge artwork")
                        .font(.system(size: 20, weight: .bold))
                    Text("Badge icons are from game-icons.net, used under the Creative Commons Attribution 3.0 licence, and recoloured for Rounds.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(BadgeArt.credits.enumerated()), id: \.element) { i, artist in
                            if i > 0 { Hairline() }
                            Text(artist)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                    }
                    .listSurface()
                    if let site = URL(string: "https://game-icons.net"), let licence = URL(string: "https://creativecommons.org/licenses/by/3.0/") {
                        VStack(alignment: .leading, spacing: 4) {
                            Link("game-icons.net", destination: site)
                            Link("CC BY 3.0 licence", destination: licence)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .tint(Theme.accentText)
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Theme.accent)
    }
}
