import SwiftUI

/// Specialty choices, one tap to pick and go back.
struct SpecialtyListView: View {
    @Binding var selection: Specialty?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(Specialty.ordered.enumerated()), id: \.element) { index, specialty in
                    if index > 0 { Hairline() }
                    Button {
                        selection = specialty
                        dismiss()
                    } label: {
                        HStack {
                            Text(specialty.label).font(.system(size: 17)).foregroundStyle(Theme.text)
                            Spacer()
                            if selection == specialty { AppIcon(.check, size: 18).foregroundStyle(Theme.accent) }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selection == specialty ? .isSelected : [])
                }
            }
            .listSurface()
            .padding(20)
        }
        .background(Theme.bg)
        .navigationTitle("Specialty")
        .navigationBarTitleDisplayMode(.inline)
    }
}
