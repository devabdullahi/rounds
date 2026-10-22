import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Sample debrief (after the pick)
 *
 *    0ms   choices fade out; the diagnosis card rises, y 12 → 0
 *  150ms   the score counts up to its value
 *  350ms   the attending's card rises
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let score = 0.15
    static let attending = 0.35
}

/// Step 4 of the sample case: make the call, then the debrief as the app draws it (diagnosis,
/// score, the attending's feedback) with Share at the top. Any pick goes on to the debrief.
struct DebriefDemoPage: View {
    var shown = true
    var onFinished: () -> Void = {}

    private let workup = SampleWorkup.soreThroat
    @State private var pick: String?
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CoachStrip(step: 4, of: 4, text: pick == nil
                           ? "Make your call. Any answer shows you the debrief."
                           : "Every case ends like this: a score, and what to fix.")
                header
                if let pick {
                    diagnosisCard(pick)
                        .rise(revealed, at: 0)
                    attendingCard
                        .rise(revealed, at: TIMING.attending)
                } else {
                    choices
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("Debrief").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
            Spacer()
            if let pick {
                ShareLink(item: workup.shareText(for: pick)) {
                    AppIcon(.share, size: 18)
                        .foregroundStyle(Theme.accentInk)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentFill, in: Circle())
                }
                .accessibilityLabel("Share my score")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you think Dana has?")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
            ForEach(workup.diagnoses, id: \.self) { d in
                Button { choose(d) } label: {
                    Text(d)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.text.opacity(0.10)))
                }
                .buttonStyle(PressDownStyle())
            }
        }
        .card()
    }

    private func diagnosisCard(_ pick: String) -> some View {
        let score = revealed ? workup.score(for: pick) : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Diagnosis").font(.system(size: 13)).foregroundStyle(Theme.muted)
            Text(workup.answer).font(.system(size: 30, weight: .bold)).tracking(-0.5)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if pick == workup.answer { AppIcon(.check, size: 13).foregroundStyle(Theme.accentText) }
                Text(workup.verdict(for: pick)).font(.system(size: 14)).foregroundStyle(Theme.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(score)").font(.system(size: 52, weight: .bold)).tracking(-1.5)
                    .contentTransition(.numericText(value: Double(score)))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(TIMING.score), value: revealed)
                Text("/100").font(.system(size: 20)).foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(workup.score(for: pick)) out of 100")
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, padding: 18)
    }

    private var attendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("MD")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .frame(width: 36, height: 36)
                    .background(Theme.text, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your attending").font(.system(size: 15, weight: .semibold))
                    Text("Feedback on this case").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            feedback(workup.good, dot: Theme.accent)
            feedback(workup.miss, dot: Theme.wrong)
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20)
    }

    private func feedback(_ f: SampleWorkup.Feedback, dot: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(dot).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.title).font(.system(size: 15, weight: .semibold))
                Text(f.detail).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func choose(_ d: String) {
        withAnimation(reduceMotion ? nil : Springs.slide) { pick = d }
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(reduceMotion ? nil : Springs.slide) { revealed = true }
        }
        onFinished()
    }
}
