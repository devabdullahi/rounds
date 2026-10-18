import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Handoff (grading wait)
 *
 * Masks grading (~4–8 s). The timeline replays the student's moves
 * while the attending reads; the button only appears once graded.
 *
 *     0ms   header fades in
 *   200ms   event 1 rises, dot pops with glow, connector grows
 *  +≤120ms  each following event; the whole timeline lands within
 *           ~1.2s however long the shift was
 *  +200ms   shift summary rises (questions, exams, tests, time)
 *  graded   "Dr. Okafor is reading your notes" swaps for the button
 *           as soon as the grade lands (no minimum wait)
 *
 * Waiting line shimmers so it reads as working, not frozen.
 * Reduce Motion: timeline shows at once, button when graded.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let firstEvent = 0.2    // s before the first row
    static let maxStagger = 0.12   // s between rows, at most
    static let rowsWithin = 1.0    // s the rows take in all, however many there are
    static let summaryAfterLast = 0.2   // s after the last event before the summary rises

    /// Gap between rows: quick for a short shift, tighter for a long one, so a 30-step case
    /// doesn't make the student wait.
    static func stagger(rows: Int) -> Double { rows > 1 ? min(maxStagger, rowsWithin / Double(rows - 1)) : 0 }
}

private enum ROW {
    static let offsetY: CGFloat = 10
    static let rise = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let dotPop = Animation.spring(response: 0.3, dampingFraction: 0.55)
    static let dotStartScale: CGFloat = 0.3
}

private enum SHIMMER {
    static let period = 1.6
    static let width: CGFloat = 0.35   // fraction of the text the highlight covers
}

struct HandoffView: View {
    @Environment(CaseRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: CaseSession

    /// The student's own shift, limited to actions the app offers:
    /// questions (accent), exams and tests (neutral), the submitted diagnosis (bold, no alarm color).
    private struct Event: Identifiable {
        let id = UUID()
        let time: String
        let text: String
        let color: Color
        var isConclusion = false
    }

    /// Built once when the screen appears, so row identities stay stable while they animate in.
    @State private var events: [Event] = []

    private func makeEvents() -> [Event] {
        let start = session.startedAt ?? .now
        let stamp = { (d: Date) in CaseSession.format(d.timeIntervalSince(start)) }
        return session.timeline.map { e in
            Event(time: stamp(e.at), text: e.kind == .exam ? "Examined: \(e.text.prefix(1).lowercased())\(e.text.dropFirst())" : e.text,
                  color: e.kind == .question ? Theme.accent : Theme.faint)
        } + [Event(time: stamp(.now), text: "Diagnosis: \(session.diagnosis)", color: Theme.text, isConclusion: true)]
    }

    // MOCK (disabled): fixed chest-pain timeline from the screens phase.
//     private struct Event: Identifiable {
//         let id = UUID()
//         let time: String
//         let text: String
//         let color: Color
//         var isConclusion = false
//     }
//
//     private let events = [
//         Event(time: "00:12", text: "Asked when the pain started", color: Theme.accent),
//         Event(time: "01:05", text: "Asked where it goes: left arm", color: Theme.accent),
//         Event(time: "02:40", text: "Smoking and family history", color: Theme.accent),
//         Event(time: "03:18", text: "Examined: heart and lungs", color: Theme.faint),
//         Event(time: "05:10", text: "Ordered an ECG", color: Theme.faint),
//         Event(time: "06:02", text: "Ordered troponin", color: Theme.faint),
//         Event(time: "07:29", text: "Diagnosis: inferior STEMI", color: Theme.text, isConclusion: true),
//     ]

    @State private var shownCount = 0
    @State private var graded = false
    /// The grading request started on arrival, awaited before "graded" shows.
    @State private var grading: Task<Grade, Error>?
    @State private var headerShown = false
    @State private var summaryShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Avatar(initials: "MD", size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Handing over to your attending").font(.system(size: 17, weight: .semibold))
                    Text("Here's how your shift went.").font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
            }
            .opacity(headerShown ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: headerShown)
            .padding(.top, 8)

            FieldLabel("Your timeline")
                .padding(.top, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                        row(e, visible: i < shownCount, isLast: i == events.count - 1)
                    }
                    shiftSummary
                        .padding(.top, 12)
                        .opacity(summaryShown ? 1 : 0)
                        .offset(y: summaryShown ? 0 : ROW.offsetY)
                        .animation(ROW.rise, value: summaryShown)
                }
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            ZStack {
                if graded {
                    Button("See your attending's notes") { router.go(.debrief) }
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                        .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity),
                                                removal: .opacity))
                } else {
                    ShimmerText(text: "Your attending is reading your notes", animate: !reduceMotion)
                        .frame(minHeight: 52)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(Springs.pop, value: graded)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .task { await play() }
    }

    /// Fills the wait with something earned: the shape of the shift at a glance.
    private var shiftSummary: some View {
        HStack(spacing: 0) {
            let count = { (k: TimelineEvent.Kind) in session.timeline.filter { $0.kind == k }.count }
            stat("\(count(.question))", count(.question) == 1 ? "Question" : "Questions")
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 32)
            stat("\(count(.exam))", count(.exam) == 1 ? "Exam" : "Exams")
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 32)
            stat("\(count(.test))", count(.test) == 1 ? "Test" : "Tests")
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 32)
            stat(CaseSession.format(session.elapsed(at: .now)), "Used")
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.mono(20))
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ e: Event, visible: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(e.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: e.color, radius: visible ? 4 : 0)
                    .scaleEffect(visible ? 1 : ROW.dotStartScale)
                    .animation(ROW.dotPop, value: visible)
                    .padding(.top, 5)
                Rectangle()
                    .fill(Theme.text.opacity(0.12))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(y: visible && !isLast ? 1 : 0, anchor: .top)
                    .animation(ROW.rise.delay(0.1), value: visible)
            }
            .frame(width: 12)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(e.time).font(.mono(13, weight: .medium)).foregroundStyle(Theme.muted).frame(width: 46, alignment: .leading)
                Text(e.text).font(.system(size: 16, weight: e.isConclusion ? .semibold : .regular)).lineSpacing(2)
            }
            .padding(.bottom, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : ROW.offsetY)
        .animation(ROW.rise, value: visible)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!visible)
    }

    private func play() async {
        // The real grading starts now, while the attending "reads"; the debrief picks up the same
        // request. Debug screens skip it (they have no attempt to submit).
        #if DEBUG
        if DebugLaunch.screen == nil { grading = Task { try await session.submit() } }
        #else
        grading = Task { try await session.submit() }
        #endif
        events = makeEvents()
        headerShown = true
        if reduceMotion {
            shownCount = events.count
        } else {
            try? await Task.sleep(for: .seconds(TIMING.firstEvent))
            let gap = TIMING.stagger(rows: events.count)
            for i in events.indices {
                shownCount = i + 1
                if i + 1 < events.count { try? await Task.sleep(for: .seconds(gap)) }
            }
        }
        if !reduceMotion { try? await Task.sleep(for: .seconds(TIMING.summaryAfterLast)) }
        summaryShown = true
        // "Graded" means the grade has landed (or failed: the debrief then shows the problem and a retry).
        _ = try? await grading?.value
        graded = true
    }
}

/// Muted label with a soft highlight sliding across it.
private struct ShimmerText: View {
    let text: String
    let animate: Bool

    var body: some View {
        let label = Text(text).font(.system(size: 15)).foregroundStyle(Theme.muted)
        if animate {
            TimelineView(.animation) { ctx in
                let p = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: SHIMMER.period) / SHIMMER.period
                label.overlay {
                    GeometryReader { geo in
                        let w = geo.size.width * SHIMMER.width
                        LinearGradient(colors: [.clear, Theme.text.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: w)
                            .offset(x: -w + CGFloat(p) * (geo.size.width + w))
                    }
                    .mask(label)
                }
            }
        } else {
            label
        }
    }
}
