import SwiftUI

/// Every badge as a trading card, binder style: earned cards face up in their rarity, the rest
/// face down with a lock and how close the student is. Tapping a card shows how to earn it.
struct BadgesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var shown: BadgeStatus?
    /// Three cards fill a row on any phone width.
    @State private var cardScale: CGFloat = 0.6

    private enum GRID {
        static let columns = 3
        static let spacing: CGFloat = 12
    }

    var body: some View {
        let all = BadgeCatalog.status(for: app.badgeRecord)
        let unlocked = all.filter(\.unlocked).count
        VStack(spacing: 0) {
            NavHeader(title: "Badges") {
                IconButton(glyph: .chevronLeft, label: "Back") { dismiss() }
            } trailing: {
                #if DEBUG
                // Test only: plays the unlock for a random locked card; nothing is earned.
                Button("Test unlock") { app.debugUnlockRandomBadge() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minHeight: 44)
                #else
                EmptyView()
                #endif
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summary(all, unlocked: unlocked)
                    closest(all)

                    ForEach(Badge.Group.allCases, id: \.self) { group in
                        let items = all.filter { $0.badge.group == group }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Eyebrow(group.label)
                                Spacer()
                                Text("\(items.filter(\.unlocked).count)/\(items.count)")
                                    .font(.mono(13, weight: .medium))
                                    .foregroundStyle(Theme.muted)
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: GRID.spacing), count: GRID.columns),
                                      spacing: GRID.spacing) {
                                ForEach(items) { status in
                                    Button { shown = status } label: { BadgeCard(status: status, scale: cardScale) }
                                        .buttonStyle(PressDownStyle())
                                        .accessibilityHint("Shows how to earn it")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .onGeometryChange(for: CGFloat.self) { $0.size.width - 40 } action: { width in
                    let cell = (width - GRID.spacing * CGFloat(GRID.columns - 1)) / CGFloat(GRID.columns)
                    cardScale = max(0.4, cell / BadgeCard.size.width)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shown) { status in
            BadgeDetail(status: status)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
        }
    }

    /// The few locked cards nearest to done, with what's left: the next targets.
    @ViewBuilder
    private func closest(_ all: [BadgeStatus]) -> some View {
        let near = BadgeCatalog.nearest(all)
        if !near.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Almost there")
                VStack(spacing: 0) {
                    ForEach(Array(near.enumerated()), id: \.element.id) { i, status in
                        if i > 0 { Hairline() }
                        Button { shown = status } label: {
                            HStack(spacing: 12) {
                                BadgeMedallion(status: status, size: 40)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(status.nudge).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                                    ProgressBar(value: status.progress, color: status.badge.rarity.ink, height: 5)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .listSurface()
            }
        }
    }

    /// Collected count, then how many of each rarity.
    private func summary(_ all: [BadgeStatus], unlocked: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(unlocked)").font(.mono(30))
                Text("of \(all.count) collected").font(.system(size: 17)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                ForEach(Badge.Rarity.allCases, id: \.self) { rarity in
                    let cards = all.filter { $0.badge.rarity == rarity }
                    VStack(spacing: 2) {
                        Text("\(cards.filter(\.unlocked).count)/\(cards.count)").font(.system(size: 15, weight: .bold))
                        Text(rarity.label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(rarity.ink.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

private struct BadgeDetail: View {
    let status: BadgeStatus

    var body: some View {
        VStack(spacing: 12) {
            BadgeCard(status: status, scale: 1.1)
                .padding(.top, 24)
            Text(status.hidden ? "A secret card. Keep practicing to find it." : status.unlocked ? status.badge.achieved : status.badge.detail)
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if status.unlocked {
                Text(status.earnedAt.map { "Earned \($0.formatted(.dateTime.month(.wide).day()))" } ?? "In your collection")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accentText)
            } else if !status.hidden {
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
