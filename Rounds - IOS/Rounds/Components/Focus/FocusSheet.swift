import SwiftUI

/// Home chip and Settings row open this: where patients are met (any, clinic, hospital), then any
/// rotations and systems, or a mix. Rows use the onboarding selection look and keep the example complaints.
struct FocusSheet: View {
    /// Conditions per topic, keyed by `StudyFocus.stored`; empty hides the counts.
    var counts: [String: Int] = [:]
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(CareSetting.storageKey) private var settingStored = ""

    @State private var bySystem = false

    private var focus: FocusSelection { FocusSelection(stored: focusStored) }
    private var setting: Binding<CareSetting> {
        Binding { CareSetting(stored: settingStored) } set: { settingStored = $0.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Study focus").font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
            }
            Text(focus.isMix ? "Pick one or more. You'll only see these patients." : "\(focus.items.count) picked · you'll only see these patients.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)

            Text("Setting")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 16)
            Segmented(options: CareSetting.allCases.map { ($0, $0.label) }, selection: setting)
                .padding(.top, 6)
            Text(setting.wrappedValue.detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)

            Text("Topics")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 16)
            Segmented(options: [(false, "Specialty"), (true, "Body systems")], selection: $bySystem)
                .padding(.top, 6)

            ScrollView {
                FocusTopicList(focus: focus, bySystem: bySystem, counts: counts) { value in
                    var next = focus
                    next.toggle(value)
                    withAnimation(Springs.pop) { focusStored = next.stored }
                } onMix: {
                    withAnimation(Springs.pop) { focusStored = FocusSelection().stored }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .onAppear { bySystem = focus.leadsWithSystem }
    }
}
