import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Debrief
 *
 *    0ms   score card scales in, 0.94 → 1.0
 *  300ms   verdict pill pops
 *  450ms   rating counts up old → new, delta badge pops
 *  900ms   attending feedback rows slide up (staggered 120ms)
 * 1500ms   summary rows fade in
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let card     = 0.00   // score card scales in
    static let verdict  = 0.30   // verdict pill pops
    static let rating   = 0.45   // rating ticks to new value
    static let feedback = 0.90   // attending notes stagger in
    static let summary  = 1.50   // streak / casebook rows
}

private enum SCORECARD {
    static let initialScale: CGFloat = 0.94
    static let spring = Springs.card
}

private enum FEEDBACK {
    static let stagger = 0.12     // s between rows
    static let offsetY: CGFloat = 14
    static let spring = Springs.slide
}

struct DebriefView: View {
    @Environment(AppState.self) private var app
    @Environment(CaseRouter.self) private var router
    let session: CaseSession

    @State private var stage = -1
    @State private var grade: Grade?
    @State private var gradingProblem: String?
    @State private var startRating = 0
    @State private var showMisses = false
    @Environment(\.reference) private var reference
    @State private var assist = ReferenceAssist()

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Debrief") {
                IconButton(glyph: .x, label: "Close") { app.finishCase() }
            } trailing: {
                ShareLink(item: shareText) {
                    AppIcon(.share, size: 18)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .glassCircle(tint: Theme.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share result card")
            }

            if let grade {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        scoreCard(grade)
                        attendingCard(grade)
                        summary(grade)
                        if !assist.topics.isEmpty { learnMore }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                        .frame(height: 32)
                        .allowsHitTesting(false)
                }
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    if let gradingProblem {
                        Text(gradingProblem).font(.system(size: 15)).foregroundStyle(Theme.warnText).multilineTextAlignment(.center)
                        Button("Try again") { Task { await play() } }
                            .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
                    } else {
                        ProgressView()
                        Text("Your attending is reviewing the case…").font(.system(size: 15)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }

            HStack(spacing: 10) {
                Button("Retry case") { restart() }
                    .buttonStyle(SoftButtonStyle())
                Button("Next patient") { app.finishCase() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Theme.bg)
        .navigationBarBackButtonHidden()
        .task { await play() }
        .task { assist.reference = reference }
    }

    /// Plain-language reading for the case's diagnosis (MedlinePlus), after the score settles.
    private var learnMore: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Learn more")
            VStack(spacing: 0) {
                ForEach(Array(assist.topics.enumerated()), id: \.element.id) { i, topic in
                    Link(destination: topic.url) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title).font(.system(size: 16, weight: .semibold))
                                Text(topic.summary).font(.system(size: 13)).foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            AppIcon(.externalLink, size: 18).foregroundStyle(Theme.faint)
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint("Opens MedlinePlus in Safari")
                    if i < assist.topics.count - 1 { Hairline() }
                }
            }
            .listSurface()
            Text("From MedlinePlus, U.S. National Library of Medicine.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
        }
        .padding(.top, 6)
        .opacity(stage >= 4 ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.15), value: stage)
    }

    private func play() async {
        guard grade == nil else { return }
        startRating = app.rating
        gradingProblem = nil
        let g: Grade
        do {
            #if DEBUG
            // A fixed, partly wrong grade, so the debrief can be checked without grading a real case.
            g = DebugLaunch.screen == "debrief-graded" ? .debugSample : try await session.submit()
            #else
            g = try await session.submit()
            #endif
        } catch {
            gradingProblem = error.localizedDescription
            return
        }
        grade = g
        // The diagnosis is only known once graded, so reading links load now.
        Task { await assist.loadTopics(for: g.diagnosis) }
        let marks = [TIMING.card, TIMING.verdict, TIMING.rating, TIMING.feedback, TIMING.summary]
        var elapsed = 0.0
        for (i, at) in marks.enumerated() {
            try? await Task.sleep(for: .seconds(at - elapsed))
            elapsed = at
            withAnimation(.easeOut(duration: 0.3)) { stage = i }
            if i == 2 { withAnimation(.snappy(duration: 0.8)) { app.record(g, session: session) } }
        }
        // Once the grade has fully landed, any badge it earned gets its moment here, at the peak.
        try? await Task.sleep(for: .seconds(0.6))
        app.debriefSettled = true
    }

    /// Closes this debrief and opens the same patient again as a fresh attempt.
    private func restart() {
        let bed = session.clinical.bed
        app.activeCase = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            await app.open(bed: bed)
        }
    }

    // MARK: Sections

    private func scoreCard(_ g: Grade) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Verdict color follows the score: green strong, neutral mixed, red only for a real miss.
            Pill(text: g.verdict,
                 fg: g.score >= 85 ? Theme.good : g.score >= 60 ? Theme.dim : Theme.warnText,
                 bg: g.score >= 85 ? Theme.goodSoft : g.score >= 60 ? Theme.track : Theme.warnSoft)
                .scaleEffect(stage >= 1 ? 1 : 0.8)
                .opacity(stage >= 1 ? 1 : 0)
                .animation(Springs.pop, value: stage)

            // Case score leads: this is what the student just earned.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(stage >= 0 ? g.score : 0)")
                        .font(.score(56))
                        .tracking(-1.5)
                        .contentTransition(.numericText(value: Double(g.score)))
                    Text("/100").font(.score(22)).foregroundStyle(Theme.muted)
                }
                Text(session.diagnosis.isEmpty ? "No diagnosis submitted" : session.diagnosis)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            // Rating is the secondary, career-level number.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Rating").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Text((stage >= 2 ? app.rating : startRating).formatted())
                        .font(.score(15))
                        .contentTransition(.numericText(value: Double(app.rating)))
                    Text(g.ratingDelta >= 0 ? "+\(g.ratingDelta)" : "\(g.ratingDelta)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(g.ratingDelta >= 0 ? Theme.good : Theme.warn)
                        .scaleEffect(stage >= 2 ? 1 : 0.6)
                        .opacity(stage >= 2 ? 1 : 0)
                        .animation(Springs.pop, value: stage)
                    Spacer()
                    Text(app.tier.toNextLabel(app.rating)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                ProgressBar(value: stage >= 2 ? app.tierProgress : RatingTier.of(startRating).progress(startRating), height: 4)
            }
            .padding(.top, 4)
        }
        .card(radius: 20, padding: 18)
        .scaleEffect(stage >= 0 ? 1 : SCORECARD.initialScale)
        .opacity(stage >= 0 ? 1 : 0)
        .animation(SCORECARD.spring, value: stage)
    }

    private func attendingCard(_ g: Grade) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // MOCK (disabled): named attending "Dr. Okafor" (AO) from the screens phase.
                Avatar(initials: "MD")
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your attending").font(.system(size: 16, weight: .semibold))
                    Text("Feedback on this case").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ForEach(Array(g.feedback.enumerated()), id: \.element.id) { i, f in
                if i > 0 { Hairline() }
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(f.tone == .good ? Theme.good : Theme.warn).frame(width: 8, height: 8).padding(.top, 7)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.title).font(.system(size: 16, weight: .semibold))
                        Text(f.detail).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .opacity(stage >= 3 ? 1 : 0)
                .offset(y: stage >= 3 ? 0 : FEEDBACK.offsetY)
                .animation(FEEDBACK.spring.delay(Double(i) * FEEDBACK.stagger), value: stage)
            }
            Color.clear.frame(height: 4)
        }
        .listSurface()
    }

    private func summary(_ g: Grade) -> some View {
        VStack(spacing: 0) {
            summaryRow("Streak", "Day \(app.streak) kept")
            Hairline()
            missesRow(g)
            Hairline()
            if !g.diagnosisCorrect || !g.missedRedFlags.isEmpty {
                // Straight from the mistake to studying it, while it still stings.
                Button { app.finishCase(reviewingMistakes: true) } label: {
                    HStack {
                        Text("Mistakes")
                        Spacer()
                        Text("Make cards").fontWeight(.semibold).foregroundStyle(Theme.accent)
                        AppIcon(.chevronRight, size: 14).foregroundStyle(Theme.faint)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Closes the case and makes flashcards from your mistakes")
                Hairline()
            }
            summaryRow("Casebook", "Patient #\(app.patientsSeen) added")
            // Almost there: the badge closest to done, so the next case has a target.
            if let next = BadgeCatalog.nearest(app.badgeStatuses, limit: 1).first {
                Hairline()
                summaryRow("Next badge", next.nudge)
            }
        }
        .listSurface()
        .opacity(stage >= 4 ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: stage)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 15))
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }

    /// "Red flags screened" expands into the same per-patient list the Patients tab shows.
    @ViewBuilder
    private func missesRow(_ g: Grade) -> some View {
        let misses = g.missedRedFlags
        if misses.isEmpty {
            HStack {
                Text("Red flags screened")
                Spacer()
                Text("All").fontWeight(.semibold).foregroundStyle(Theme.good)
            }
            .font(.system(size: 15))
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Button { withAnimation(DISCLOSURE.open) { showMisses.toggle() } } label: {
                    HStack {
                        Text("Red flags screened").foregroundStyle(Theme.text)
                        Spacer()
                        Text("Missed \(misses.count)").fontWeight(.semibold).foregroundStyle(Theme.warn)
                        DisclosureChevron(open: showMisses)
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint(showMisses ? "Hide what you missed" : "Show what you missed")

                if showMisses {
                    let covered = Set(g.feedback.compactMap(\.coversMiss))
                    let rest = misses.filter { !covered.contains($0.flag) }
                    VStack(alignment: .leading, spacing: 12) {
                        if !covered.isEmpty {
                            Text("\(covered.sorted().joined(separator: ", ")): see your attending above.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .disclosureItem(0)
                        }
                        ForEach(Array(rest.enumerated()), id: \.element.id) { i, m in
                            MissItem(miss: m).disclosureItem(i + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
            .clipped()
        }
    }

    private var shareText: String {
        guard let grade else { return "Rounds" }
        return "Rounds: \(grade.score)/100 on \(session.clinical.name), \(session.clinical.age). \(grade.verdict)."
    }
}
