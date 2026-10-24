import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Debrief (story cards)
 *
 * One card at a time: Verdict → Fix next time → Your points → Go deeper.
 * Swipe or tap the button to move on; dashes at the top show where you are.
 *
 * VERDICT CARD
 *    0ms   card scales in, 0.94 → 1.0 (the diagnosis in large type first)
 *  300ms   verdict pill pops, score counts up
 *  450ms   rating counts up old → new, delta badge pops
 * 1200ms   settled: any badge the grade earned takes its moment
 *
 * Later cards slide in with the page. Reduce Motion: fades only, pages change without sliding.
 * Older grades have no breakdown or misses: those cards are skipped.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let card    = 0.00   // verdict card scales in
    static let verdict = 0.30   // pill pops, score counts up
    static let rating  = 0.45   // rating ticks to new value
    static let settled = 1.20   // everything has landed
}

/// Stage index reached at each TIMING mark, so sections read by name rather than by number.
private enum STAGE {
    static let card = 0, verdict = 1, rating = 2, settled = 3
}

private enum SCORECARD {
    static let initialScale: CGFloat = 0.94
    static let spring = Springs.card
}

/// The debrief's cards, in the order they're shown.
private enum DebriefCard: Hashable {
    case verdict, fix, points, deeper

    var label: String {
        switch self {
        case .verdict: "Verdict"
        case .fix: "Fix next time"
        case .points: "Your points"
        case .deeper: "Go deeper"
        }
    }

    /// The button that moves on to this card.
    var nextTitle: String {
        switch self {
        case .verdict: "See the verdict"
        case .fix: "See what to fix"
        case .points: "See your points"
        case .deeper: "Go deeper"
        }
    }
}

/// The sections behind "Go deeper", each opened in place.
private enum DeeperSection: Hashable {
    case notes, differential, lens, about
}

struct DebriefView: View {
    @Environment(AppState.self) private var app
    @Environment(CaseRouter.self) private var router
    let session: CaseSession

    @State private var stage = -1
    @State private var grade: Grade?
    @State private var gradingProblem: String?
    @State private var startRating = 0
    @State private var openSections: Set<DeeperSection> = []
    @State private var card: DebriefCard = .verdict
    @Environment(\.reference) private var reference
    @State private var assist = ReferenceAssist()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if let grade {
                let cards = cards(for: grade)
                let index = cards.firstIndex(of: card) ?? 0
                header(cards: cards, index: index)
                TabView(selection: $card) {
                    ForEach(cards, id: \.self) { c in
                        ScrollView {
                            page(c, grade)
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                                .padding(.bottom, 16)
                        }
                        .scrollIndicators(.hidden)
                        .tag(c)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : Springs.slide, value: card)
                bottomBar(cards: cards, index: index)
            } else {
                NavHeader(title: "Debrief") {
                    IconButton(glyph: .x, label: "Close") { app.finishCase() }
                } trailing: { EmptyView() }
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
        }
        .background(Theme.bg)
        .navigationBarBackButtonHidden()
        .task { await play() }
        .task { assist.reference = reference }
        #if DEBUG
        .task(id: stage) {
            // Screenshots: `-screen debrief-deeper` opens the last card with every section open;
            // `-screen debrief-tour` steps through every card, 2.5 s each.
            guard stage == STAGE.settled, let grade else { return }
            if DebugLaunch.screen == "debrief-deeper" {
                card = .deeper
                openSections = [.notes, .differential, .lens, .about]
            } else if DebugLaunch.screen == "debrief-tour" {
                for c in cards(for: grade).dropFirst() {
                    try? await Task.sleep(for: .seconds(2.5))
                    go(to: c)
                }
            }
        }
        #endif
    }

    /// The cards this grade has: misses and points only when there are some (older grades have no breakdown).
    private func cards(for g: Grade) -> [DebriefCard] {
        var cards: [DebriefCard] = [.verdict]
        if !fixItems(g).isEmpty { cards.append(.fix) }
        if !g.breakdown.isEmpty { cards.append(.points) }
        cards.append(.deeper)
        return cards
    }

    /// Dashes for where you are, the card's name, and share and close.
    private func header(cards: [DebriefCard], index: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(cards.enumerated()), id: \.offset) { i, _ in
                    Capsule()
                        .fill(i <= index ? Theme.text : Theme.track)
                        .frame(height: 4)
                }
            }
            .animation(.easeOut(duration: 0.25), value: index)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Card \(index + 1) of \(cards.count)")
            .padding(.horizontal, 20)
            .padding(.top, 8)
            HStack(spacing: 4) {
                Text("\(card.label) · \(index + 1) of \(cards.count)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.opacity)
                Spacer()
                ShareLink(item: shareText) {
                    AppIcon(.share, size: 18)
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share result card")
                Button { app.finishCase() } label: {
                    AppIcon(.x, size: 18)
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
        }
    }

    @ViewBuilder
    private func page(_ c: DebriefCard, _ g: Grade) -> some View {
        switch c {
        case .verdict: verdictCard(g)
        case .fix: fixNextTime(g)
        case .points: breakdown(g)
        case .deeper:
            VStack(alignment: .leading, spacing: 14) {
                goDeeper(g)
                if !assist.topics.isEmpty { learnMore }
                casebookNote
            }
        }
    }

    /// Before the last card: the next card is the main action, with a way to the end. On it: retry or move on.
    private func bottomBar(cards: [DebriefCard], index: Int) -> some View {
        let next = index + 1 < cards.count ? cards[index + 1] : nil
        return HStack(spacing: 10) {
            if let next {
                Button("See all") { go(to: cards[cards.count - 1]) }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityHint("Goes to the last card")
                Button(next.nextTitle) { go(to: next) }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Retry") { restart() }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Retry case")
                Button("Next patient") { app.finishCase() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func go(to c: DebriefCard) {
        withAnimation(reduceMotion ? nil : Springs.slide) { card = c }
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
        .padding(.top, 2)
    }

    private func play() async {
        guard grade == nil else { return }
        startRating = app.rating
        gradingProblem = nil
        let g: Grade
        do {
            #if DEBUG
            // A fixed, partly wrong grade, so the debrief can be checked without grading a real case.
            if ["debrief-graded", "debrief-deeper", "debrief-tour"].contains(DebugLaunch.screen) {
                session.diagnosis = Grade.debugSample.diagnosis   // as if the student had submitted it
                g = .debugSample
            } else {
                g = try await session.submit()
            }
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
        let marks = [TIMING.card, TIMING.verdict, TIMING.rating, TIMING.settled]
        var elapsed = 0.0
        for (i, at) in marks.enumerated() {
            try? await Task.sleep(for: .seconds(at - elapsed))
            elapsed = at
            withAnimation(.easeOut(duration: 0.3)) { stage = i }
            if i == STAGE.rating { withAnimation(.snappy(duration: 0.8)) { app.record(g, session: session) } }
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

    private func verdictCard(_ g: Grade) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            AppIcon(g.diagnosisCorrect ? .check : .x, size: 32)
                .foregroundStyle(g.diagnosisCorrect ? Theme.good : Theme.warnText)
                .frame(width: 64, height: 64)
                .background(g.diagnosisCorrect ? Theme.goodSoft : Theme.warnSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                // Verdict color follows the score: green strong, neutral mixed, red only for a real miss.
                Pill(text: g.verdict,
                     fg: g.score >= 85 ? Theme.good : g.score >= 60 ? Theme.dim : Theme.warnText,
                     bg: g.score >= 85 ? Theme.goodSoft : g.score >= 60 ? Theme.track : Theme.warnSoft)
                    .scaleEffect(stage >= STAGE.verdict ? 1 : 0.8)
                    .opacity(stage >= STAGE.verdict ? 1 : 0)
                    .animation(Springs.pop, value: stage)
                // The answer leads: once graded, the case's real diagnosis is the first thing the student reads.
                Text(g.diagnosis)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 6) {
                    AppIcon(g.diagnosisCorrect ? .check : .x, size: 14)
                        .foregroundStyle(g.diagnosisCorrect ? Theme.good : Theme.warnText)
                    Text(session.diagnosis.isEmpty ? "No diagnosis submitted" : "You said \(session.diagnosis)")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(g.diagnosisCorrect ? "Correct. You said \(session.diagnosis)" : "Not correct. You said \(session.diagnosis.isEmpty ? "nothing" : session.diagnosis)")
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(stage >= STAGE.verdict ? g.score : 0)")
                    .font(.score(72))
                    .tracking(-2)
                    .contentTransition(.numericText(value: Double(g.score)))
                Text("/100").font(.score(22)).foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Score \(g.score) out of 100")

            // Rating is the secondary, career-level number.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    chip {
                        Text("Rating \((stage >= STAGE.rating ? app.rating : startRating).formatted())")
                            .contentTransition(.numericText(value: Double(app.rating)))
                        Text(g.ratingDelta >= 0 ? "+\(g.ratingDelta)" : "\(g.ratingDelta)")
                            .foregroundStyle(g.ratingDelta >= 0 ? Theme.good : Theme.warn)
                            .scaleEffect(stage >= STAGE.rating ? 1 : 0.6)
                            .opacity(stage >= STAGE.rating ? 1 : 0)
                            .animation(Springs.pop, value: stage)
                    }
                    chip { Text("Streak day \(app.streak)") }
                }
                ProgressBar(value: stage >= STAGE.rating ? app.tierProgress : RatingTier.of(startRating).progress(startRating), height: 6)
                Text(app.tier.toNextLabel(app.rating)).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
        }
        .card(radius: 28, padding: 24)
        .scaleEffect(stage >= STAGE.card ? 1 : SCORECARD.initialScale)
        .opacity(stage >= STAGE.card ? 1 : 0)
        .animation(SCORECARD.spring, value: stage)
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) { content() }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Points per part, in the order the case is played. Older grades have none, so nothing shows.
    @ViewBuilder
    private func breakdown(_ g: Grade) -> some View {
        let rows = ScoreCategory.allCases.compactMap { c in
            g.breakdown[c].map { ScoreBreakdownCard.Row(label: c.shortLabel, got: $0.got, max: $0.max) }
        }
        if !rows.isEmpty {
            ScoreBreakdownCard(rows: rows)
        }
    }

    /// The attending's misses first, then any red flag no note already explains.
    private func fixItems(_ g: Grade) -> [FixNextTimeCard.Item] {
        let notes = g.feedback.filter { $0.tone == .miss }
            .map { FixNextTimeCard.Item(title: $0.title, detail: $0.detail, isFocus: $0.isFocus) }
        let covered = Set(g.feedback.compactMap(\.coversMiss))
        let flags = g.missedRedFlags.filter { !covered.contains($0.flag) }
            .map { FixNextTimeCard.Item(title: "Screen for \($0.flag.lowercased())", detail: $0.why) }
        return notes + flags
    }

    private func fixNextTime(_ g: Grade) -> some View {
        // Straight from the mistake to studying it, while it still stings.
        FixNextTimeCard(items: fixItems(g),
                        makeCards: !g.diagnosisCorrect || !g.missedRedFlags.isEmpty ? { app.finishCase(reviewingMistakes: true) } : nil)
    }

    /// Everything that teaches, one row each, opened in place so the first screen stays short.
    private func goDeeper(_ g: Grade) -> some View {
        let unlisted = g.differential.filter { $0.mustNotMiss && !$0.inYours }.count
        return VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                DebriefSectionRow(glyph: .messageSquare, tint: Theme.dim, title: "Your attending's notes",
                                  note: "\(g.feedback.count)", open: openSections.contains(.notes)) { toggle(.notes) }
                if openSections.contains(.notes) { attendingNotes(g).disclosureItem(0) }
                if !g.differential.isEmpty {
                    Hairline()
                    DebriefSectionRow(glyph: .siren, tint: unlisted > 0 ? Theme.warn : Theme.dim, title: "Your differential",
                                      note: unlisted > 0 ? "\(unlisted) must-not-miss" : nil, noteTint: Theme.warnText,
                                      open: openSections.contains(.differential)) { toggle(.differential) }
                    if openSections.contains(.differential) {
                        DifferentialReviewCard(items: g.differential, extrasNote: DifferentialReview.extrasNote(g.yourExtras), framed: false)
                            .disclosureItem(0)
                    }
                }
                if let lens = g.lens {
                    Hairline()
                    DebriefSectionRow(glyph: .target, tint: Theme.accent, title: lens.title,
                                      open: openSections.contains(.lens)) { toggle(.lens) }
                    if openSections.contains(.lens) { ExamLensCard(lens: lens, framed: false).disclosureItem(0) }
                }
                if let about = g.about {
                    Hairline()
                    DebriefSectionRow(glyph: .bookOpen, tint: Theme.accent, title: "About \(g.diagnosis)",
                                      open: openSections.contains(.about)) { toggle(.about) }
                    if openSections.contains(.about) {
                        ConditionAboutCard(diagnosis: g.diagnosis, about: about, framed: false).disclosureItem(0)
                    }
                }
            }
            .listSurface()
            .clipped()
        }
    }

    private func toggle(_ section: DeeperSection) {
        withAnimation(reduceMotion ? nil : DISCLOSURE.open) {
            if openSections.contains(section) { openSections.remove(section) } else { openSections.insert(section) }
        }
    }

    /// Every note from the attending, good and missed, as it was written.
    private func attendingNotes(_ g: Grade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(g.feedback) { f in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(f.tone == .good ? Theme.good : Theme.warn).frame(width: 8, height: 8).padding(.top, 7)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.title).font(.system(size: 16, weight: .semibold))
                        Text(f.detail).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(f.tone == .good ? "Did well" : "Missed"): \(f.title). \(f.detail)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    /// The case's place in the record, and the badge closest to done, so the next case has a target.
    private var casebookNote: some View {
        let next = BadgeCatalog.nearest(app.badgeStatuses, limit: 1).first
        return Text(next.map { "Patient #\(app.patientsSeen) added to your casebook. \($0.nudge)" } ?? "Patient #\(app.patientsSeen) added to your casebook.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var shareText: String {
        guard let grade else { return "Rounds" }
        return "Rounds: \(grade.score)/100 on \(session.clinical.name), \(PatientAge.label(session.clinical.age)). \(grade.verdict)."
    }
}
