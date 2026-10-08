import SwiftUI

/// One missed red flag and why it matters. Same row on Patients and Debrief.
struct MissItem: View {
    let miss: Miss
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.warn).frame(width: 6, height: 6).padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(miss.flag).font(.system(size: 15, weight: .semibold))
                Text(miss.why).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
