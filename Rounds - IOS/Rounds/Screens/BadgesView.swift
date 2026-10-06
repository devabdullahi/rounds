import SwiftUI

/// Every badge there is, achievement-screen style: earned ones in color, the rest dimmed under a
/// lock with how close the student is. Tapping one shows how to earn it.
struct BadgesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var shown: BadgeStatus?

    private var statuses: [BadgeStatus] { BadgeCatalog.status(for: app.badgeRecord) }
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        let all = statuses
        let unlocked = all.filter(\.unlocked).count
        VStack(spacing: 0) {
            NavHeader(title: "Badges") {
                IconButton(glyph: .chevronLeft, label: "Back") { dismiss() }
            } trailing: { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(unlocked)").font(.mono(30))
                            Text("of \(all.count) unlocked").font(.system(size: 17)).foregroundStyle(Theme.muted)
                        }
                        ProgressBar(value: Double(unlocked) / Double(max(1, all.count)))
                    }
                    .card()
                    .accessibilityElement(children: .combine)

                    ForEach(Badge.Group.allCases, id: \.self) { group in
                        let items = all.filter { $0.badge.group == group }
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(group.label)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { status in
                                    Button { shown = status } label: { BadgeTile(status: status) }
                                        .buttonStyle(PressDownStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shown) { status in
            BadgeDetail(status: status)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }
}

/// The badge's mark: colored when earned; dimmed with a lock on top when not.
struct BadgeMedallion: View {
    let status: BadgeStatus
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(status.unlocked ? Theme.accent.opacity(0.16) : Theme.text.opacity(0.06))
            Circle()
                .strokeBorder(status.unlocked ? Theme.accent.opacity(0.55) : Theme.text.opacity(0.10), lineWidth: 2)
            AppIcon(status.badge.glyph, size: size * 0.42)
                .foregroundStyle(status.unlocked ? Theme.accent : Theme.faint)
                .opacity(status.unlocked ? 1 : 0.45)
            if !status.unlocked {
                // The lock sits on the badge, as on a console achievement list.
                AppIcon(.lock, size: size * 0.2)
                    .foregroundStyle(.white)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(Theme.faint, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct BadgeTile: View {
    let status: BadgeStatus

    var body: some View {
        VStack(spacing: 8) {
            BadgeMedallion(status: status)
            Text(status.badge.name)
                .font(.system(size: 13, weight: status.unlocked ? .semibold : .regular))
                .foregroundStyle(status.unlocked ? Theme.text : Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(status.unlocked ? "Unlocked" : status.progressLabel)
                .font(.mono(12, weight: .medium))
                .foregroundStyle(status.unlocked ? Theme.accentText : Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.badge.name), \(status.unlocked ? "unlocked" : "locked, \(status.progressLabel)")")
        .accessibilityHint("Shows how to earn it")
    }
}

private struct BadgeDetail: View {
    let status: BadgeStatus

    var body: some View {
        VStack(spacing: 14) {
            BadgeMedallion(status: status, size: 96)
                .padding(.top, 28)
            Text(status.badge.name).font(.system(size: 22, weight: .bold))
            Text(status.badge.detail)
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if status.unlocked {
                Text("Unlocked").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accentText)
            } else {
                VStack(spacing: 6) {
                    ProgressBar(value: status.progress)
                    Text(status.progressLabel).font(.mono(13, weight: .medium)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: 220)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }
}
