import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Badge haul ("Accept all")
 *
 *    0ms   scrim fades in
 *  100ms   title rises, y 12 → 0
 *  200ms   cards deal in left to right, each 90ms after the last:
 *          y 40 → 0, scale 0.85 → 1, opacity 0 → 1 (spring)
 *  after   the button rises once the last card has landed
 *
 * Reduce Motion: everything shows at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let title = 0.10
    static let firstCard = 0.20
    static let stagger = 0.09
    static let buttonAfterLast = 0.25
}

private enum DEAL {
    static let offsetY: CGFloat = 40
    static let scale: CGFloat = 0.85
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.78)
    static let cardScale: CGFloat = 0.78
}

/// Every badge waiting to be revealed, lined up at once, for a student who tapped "Accept all"
/// rather than watch each unlock. One button adds them all to the collection.
struct BadgeHaulView: View {
    let statuses: [BadgeStatus]
    let onCollect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = 0
    @State private var showTitle = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 28) {
                Text(statuses.count == 1 ? "You earned a card" : "You earned \(statuses.count) cards")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 12)
                    .accessibilityAddTraits(.isHeader)

                // A few cards sit centred; more than fit scroll sideways.
                ViewThatFits(in: .horizontal) {
                    row
                    // Unclipped, so each card's glow isn't cut off at the scroll view's edge.
                    ScrollView(.horizontal) { row }.scrollIndicators(.hidden).scrollClipDisabled()
                }

                Button("Add all to collection", action: onCollect)
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .padding(.horizontal, 32)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 12)
                    .allowsHitTesting(showButton)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .sensoryFeedback(.impact(weight: .light), trigger: dealt)
        .sensoryFeedback(.success, trigger: showButton) { _, new in new }
        .task { await play() }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(Array(statuses.enumerated()), id: \.element.id) { i, status in
                card(status)
                    .opacity(i < dealt ? 1 : 0)
                    .scaleEffect(i < dealt ? 1 : DEAL.scale)
                    .offset(y: i < dealt ? 0 : DEAL.offsetY)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)   // room for the glow
    }

    /// The card alone: its face already carries the name and rarity.
    private func card(_ status: BadgeStatus) -> some View {
        BadgeCard(status: status, scale: DEAL.cardScale)
            .shadow(color: status.badge.rarity.ink.opacity(0.55), radius: 18)
    }

    private func play() async {
        if reduceMotion {
            showTitle = true; dealt = statuses.count; showButton = true
            return
        }
        let start = ContinuousClock.now
        func wait(_ seconds: Double) async -> Bool {
            try? await Task.sleep(until: start + .seconds(seconds), clock: .continuous)
            return !Task.isCancelled
        }
        guard await wait(TIMING.title) else { return }
        withAnimation(.easeOut(duration: 0.3)) { showTitle = true }
        for i in statuses.indices {
            guard await wait(TIMING.firstCard + Double(i) * TIMING.stagger) else { return }
            withAnimation(DEAL.spring) { dealt = i + 1 }
        }
        let last = TIMING.firstCard + Double(max(0, statuses.count - 1)) * TIMING.stagger
        guard await wait(last + TIMING.buttonAfterLast) else { return }
        withAnimation(.easeOut(duration: 0.3)) { showButton = true }
    }
}
