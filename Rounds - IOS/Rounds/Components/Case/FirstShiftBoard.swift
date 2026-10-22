import SwiftUI

/// The first day's patients as a ward board: bed, who, why they came in, and whether they're new.
/// Shown on Home until the first case is graded. Takes plain values, never AppState.
struct FirstShiftBoard: View {
    struct Bed: Identifiable {
        let id: String
        let who: String
        let why: String
        let isNew: Bool
    }

    let date: Date
    let beds: [Bed]
    let seen: Int
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("WARD BOARD").tracking(1.4)
                Spacer()
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.twoDigits).day()).uppercased())
                    .monospacedDigit()
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Theme.info)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.info).frame(height: 2) }

            ForEach(Array(beds.prefix(3).enumerated()), id: \.element.id) { i, bed in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.info)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(Theme.info, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(bed.who).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text(bed.why).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(bed.isNew ? "New" : "Waiting")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(bed.isNew ? Theme.accentInk : Theme.accentText)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(bed.isNew ? Theme.accentFill : Theme.accentSoft, in: Capsule())
                }
                .frame(minHeight: 56)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }

            HStack {
                Text("Today's goal")
                Spacer()
                Text("\(seen) of \(goal) seen").fontWeight(.semibold).foregroundStyle(Theme.text).monospacedDigit()
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.top, 10)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.border))
    }
}
