import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Interview message
 *
 *    0ms   your question slides in from right, y 12 → 0
 *  ~700ms  typing dots bounce (staggered 150ms, looping)
 * ~1000ms  patient reply replaces dots, slides in from left
 *   +0ms   "Revealed" chip pops in, scale 0.8 → 1
 * ───────────────────────────────────────────────────────── */

private enum BUBBLE {
    static let offsetY: CGFloat = 12        // px a new bubble rises from
    static let maxWidth: CGFloat = 0.78     // fraction of row width
}

private enum VOICEPANEL {
    static let orbArea: CGFloat = 190            // room for rings to ripple out
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

private enum MONITOR {
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.9)   // hides while typing
}

private enum REVEAL {
    static let initialScale: CGFloat = 0.8
}

struct InterviewView: View {
    @Environment(CaseRouter.self) private var router
    let session: CaseSession

    /// Ask, Examine or Tests, picked on the step bar at the bottom.
    @State private var tab: WorkupStep = .ask
    @State private var showingFindings = false
    @State private var draft = ""
    /// The suggested questions stay folded behind "Questions to try": shown up front, students took
    /// them for the only things they could ask.
    @State private var showingIdeas = false
    @FocusState private var inputFocused: Bool
    @State private var voice = VoiceController()
    /// Live voice (real-time, interruptible). Tried first; turn-by-turn `voice` is the fallback.
    @State private var live: LiveVoice?
    /// Patient replies already in the chat when the last spoken question went out; only a newer one is
    /// the answer to speak (the question itself changes the message count first).
    @State private var repliesBeforeQuestion = 0
    @AppStorage(Preferences.showRevealsKey) private var showReveals = Preferences.showRevealsDefault
    @AppStorage(Preferences.showCoverageKey) private var showCoverage = Preferences.showCoverageDefault
    @AppStorage(Preferences.voiceModeKey) private var voiceMode = Preferences.voiceModeDefault
    @AppStorage(Preferences.autoSendKey) private var autoSend = Preferences.autoSendDefault

    private var c: ClinicalCase { session.clinical }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // The patient on the monitor while you talk. It steps aside while typing, when the
            // keyboard leaves the chat little room.
            if tab == .ask && !inputFocused {
                PatientMonitor(vitals: c.vitals)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Group {
                switch tab {
                case .ask: chat
                case .examine: examine
                case .tests: TestsPanel(session: session)
                }
            }
            .frame(maxHeight: .infinity)
            if tab == .ask {
                if isVoiceActive {
                    voicePanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    composer
                        .transition(.opacity)   // pops out at once so the panel isn't waiting on it
                }
            }
            // Every step one tap away. It steps aside for the keyboard and a voice conversation,
            // which need the room and only happen while asking.
            if !inputFocused && !isVoiceActive {
                stepBar.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(VOICEPANEL.spring, value: isVoiceActive)
        .animation(MONITOR.spring, value: inputFocused)
        .background(Theme.bg)
        .onDisappear { endVoice() }
        .onChange(of: session.messages.count) {
            // Asked aloud, the answer's voice comes with it; only the older two-request path waits here.
            guard voice.phase == .thinking, voice.askAloud == nil else { return }
            let replies = session.messages.filter { $0.kind == .patient }
            if replies.count > repliesBeforeQuestion, let reply = replies.last {
                // The patient answered the spoken question: say it out loud.
                voice.speak(reply.text)
            } else if session.messages.last?.kind == .problem {
                // The question failed; stop waiting on an answer that won't come (the error shows in the chat).
                voice.end()
            }
        }
        .onAppear {
            if live == nil {
                live = LiveVoice(
                    open: { [session] offer in try await session.startLiveCall(offer: offer) },
                    logTurn: { [session] call, question, reply in await session.logLiveTurn(call: call, question: question, reply: reply) },
                    close: { [session] call in session.endLiveCall(call) },
                    makeTransport: { RealtimeClient() })
            }
            voice.onUtterance = { [session] text in
                repliesBeforeQuestion = session.messages.filter { $0.kind == .patient }.count
                session.ask(text)
            }
            voice.usePatient(sex: c.sex, age: c.age, seed: c.bed)
            // The server voices the patient; Apple's speech is the fallback.
            voice.spokenReply = { [session] in try await session.spokenReply() }
            voice.streamedReply = { [session] in try await session.streamedReply() }
            voice.askAloud = { [session] question in await session.askAloud(question) }
            session.startClockIfNeeded()
            tab = .ask
            #if DEBUG
            if DebugLaunch.screen == "examine" { tab = .examine }
            if DebugLaunch.screen == "workup" { tab = .tests }
            if DebugLaunch.screen == "interview-nudge" { session.debugSeedHistory() }
            if DebugLaunch.screen == "interview-ideas" { showingIdeas = true }
            if DebugLaunch.screen == "interview-exam" { session.examMode = true }
            if DebugLaunch.screen == "interview-findings" {
                Task { try? await Task.sleep(for: .seconds(1)); showingFindings = true }
            }
            if DebugLaunch.screen == "voice-listen" { voice.debugPin(.listening, level: 0.75, transcript: "Any sweating or feeling sick?") }
            if DebugLaunch.screen == "voice-patient" { voice.debugPin(.patientSpeaking, level: 0.5) }
            if DebugLaunch.screen == "voice-live" { live?.debugPin(.patientSpeaking, level: 0.5, caption: "It started last night, right around my belly button.") }
            #endif
        }
        .onChange(of: tab) { _, new in
            if new != .ask { endVoice() }
        }
        // The tests menu loads now, so the step bar can show its count before Tests is opened.
        .task { await session.loadMenu() }
    }

    // MARK: Header

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                IconButton(glyph: .chevronLeft, label: "Back to door note") { router.back() }
                    .frame(width: 64, alignment: .leading)
                    .padding(.leading, 5)   // circle edge on the 20pt margin (12 bar padding + 5 + 3pt inset)
                Spacer()
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text("\(c.name), \(PatientAge.label(c.age))").font(.system(size: 17, weight: .semibold))
                        // Says why the screen is bare: no suggestions, no findings until the debrief.
                        if session.examMode {
                            Text("Exam")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.track, in: Capsule())
                                .accessibilityLabel("Exam mode")
                        }
                    }
                    // One line: the demeanor is a cue, not a paragraph.
                    Text(c.demeanor)
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                CountdownLabel(session: session).frame(width: 64, alignment: .trailing)
            }
            // History's own progress: shown while talking, not over the exam or tests.
            if tab == .ask {
                Group {
                    // With the meter turned off, the plain question count keeps the header's shape.
                    if session.examMode || !showCoverage { questionCount } else { coverageMeter }
                }
                .padding(.horizontal, 8)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(Theme.surface.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1) }
    }

    /// Exam mode's sense of pace: how much has been asked, saying nothing about coverage.
    private var questionCount: some View {
        let asked = session.messages.filter { $0.kind == .doctor }.count
        return Text(asked == 1 ? "1 question asked" : "\(asked) questions asked")
            .font(.system(size: 13)).foregroundStyle(Theme.muted)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Facts found so far, in the order they turned up (the reveal chips in the chat).
    private var findings: [String] { session.messages.filter { $0.kind == .reveal }.map(\.text) }

    /// Tapping the meter lists what's been found, so a long chat needn't be scrolled back through.
    private var coverageMeter: some View {
        Button { showingFindings = true } label: { coverageBar }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Shows the findings so far")
            .popover(isPresented: $showingFindings, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Found so far").font(.system(size: 15, weight: .semibold))
                    if findings.isEmpty {
                        Text("Nothing yet. Findings appear as the patient tells you.")
                            .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    } else {
                        ForEach(findings, id: \.self) { f in
                            HStack(spacing: 8) {
                                AppIcon(.check, size: 14).foregroundStyle(Theme.accent)
                                Text(f).font(.system(size: 15))
                            }
                        }
                    }
                }
                .padding(16)
                .frame(minWidth: 240, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
    }

    private var coverageBar: some View {
        let (got, total) = session.historyCoverage
        return HStack(spacing: 10) {
            Text("Key history").font(.system(size: 13)).foregroundStyle(Theme.muted)
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i < got ? Theme.accent : Theme.track)
                        .frame(height: 4)
                }
            }
            .animation(Springs.pop, value: got)
            Text("\(got)/\(total)").font(.mono(13, weight: .medium)).foregroundStyle(got == total ? Theme.accent : Theme.dim)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key history covered: \(got) of \(total)")
    }

    // MARK: History chat

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if session.messages.isEmpty {
                        Text(session.examMode ? "Introduce yourself, then take a focused history."
                                              : "Introduce yourself, then take a focused history. Type or say any question.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                    }
                    ForEach(session.messages) { m in
                        bubble(m).id(m.id)
                    }
                    if session.showsTypingDots {
                        TypingDots()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .offset(y: BUBBLE.offsetY)))
                            .id("typing")
                    }
                    nudge
                    Color.clear.frame(height: 24).id("bottom")
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // Older messages fade out under the monitor instead of being sliced at its edge.
            .overlay(alignment: .top) {
                LinearGradient(colors: [Theme.bg, Theme.bg.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                    .allowsHitTesting(false)
            }
            .onChange(of: session.messages.count) {
                withAnimation(Springs.slide) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: session.isPatientTyping) {
                withAnimation(Springs.slide) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            // A streamed reply grows in place: keep its newest line in view.
            .onChange(of: session.messages.last?.text) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    /// The step bar's hint, said in the chat: once the history is underway, a card that points at
    /// the exam (or, after the exam, the tests). Exam mode has no hints, so no card.
    @ViewBuilder
    private var nudge: some View {
        if !session.examMode, !session.showsTypingDots, let step = stepHint,
           let words = WorkupStep.nudge(for: step, firstManeuver: ExamRegion.grouped(c.exam).first?.maneuvers.first?.title, sex: c.sex) {
            NudgeCard(glyph: step == .examine ? .stethoscope : .flask, title: words.title, detail: words.detail,
                      actionTitle: step == .examine ? "Examine" : "Tests") {
                withAnimation(Springs.slide) { tab = step }
            }
            .padding(.top, 6)
            .transition(.opacity.combined(with: .offset(y: BUBBLE.offsetY)))
            .id("nudge")
        }
    }

    /// The step worth trying next (`WorkupStep.hint`), shared by the step bar's dot and the chat's card.
    private var stepHint: WorkupStep? {
        WorkupStep.hint(questionsAsked: session.messages.filter { $0.kind == .doctor }.count,
                        examDone: session.examDone.done, testsDone: session.testOrder.count)
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        switch m.kind {
        case .doctor:
            Text(m.text)
                .font(.system(size: 16))
                .lineSpacing(2)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.bubbleMe, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 4, topTrailingRadius: 18))
                .containerRelativeFrame(.horizontal, alignment: .trailing) { w, _ in w * BUBBLE.maxWidth }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.asymmetric(insertion: .offset(x: 20, y: BUBBLE.offsetY).combined(with: .opacity), removal: .opacity))
        case .patient:
            Text(m.text)
                .font(.system(size: 16))
                .lineSpacing(2)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18))
                .containerRelativeFrame(.horizontal, alignment: .leading) { w, _ in w * BUBBLE.maxWidth }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(insertion: .offset(x: -20, y: BUBBLE.offsetY).combined(with: .opacity), removal: .opacity))
        case .reveal:
            // Exam mode never adds reveal messages; this is the Settings switch for practice mode.
            if showReveals {
                Pill(text: m.text, glyph: .check)
                    .frame(maxWidth: .infinity)
                    .transition(.scale(scale: REVEAL.initialScale).combined(with: .opacity).animation(Springs.pop))
            }
        case .problem:
            // A failed request: say what went wrong so the student can resend.
            Pill(text: m.text, fg: Theme.warnText, bg: Theme.warn.opacity(0.12), glyph: .circleX)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        }
    }

    /// One big card, field on top and its actions below: a box that reads as "type anything here",
    /// with the suggested questions folded behind "Questions to try" so they don't look like the
    /// only things a student can ask.
    private var composer: some View {
        VStack(spacing: 8) {
            // Exam mode is unassisted: no suggested questions.
            if offersIdeas && showingIdeas {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(unaskedSuggestions, id: \.self) { s in
                            // Fills the field instead of sending, so it reads as the student's own question to edit.
                            Button(s) {
                                draft = s
                                showingIdeas = false
                                inputFocused = true
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .glassCapsule(tint: Theme.neutralFill)
                            .buttonStyle(PressDownStyle())
                            .disabled(session.isPatientTyping)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .trailingFade()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $draft, prompt: Text("Ask \(c.firstName) a question\u{2026}").foregroundStyle(Theme.faint), axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                    .accessibilityLabel("Ask \(c.firstName) a question")
                    // A multi-line field takes Return as a newline; treat it as Send, like the old one-line field.
                    .onChange(of: draft) { _, now in
                        if now.contains("\n") {
                            draft = now.replacingOccurrences(of: "\n", with: "")
                            send()
                        }
                    }
                HStack(spacing: 8) {
                    if offersIdeas {
                        Button { showingIdeas.toggle() } label: {
                            HStack(spacing: 6) {
                                AppIcon(.lightbulb, size: 16)
                                Text("Questions to try")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .glassCapsule(tint: Theme.neutralFill)
                        }
                        .buttonStyle(PressDownStyle())
                        .accessibilityHint(showingIdeas ? "Hides the suggested questions" : "Shows a few questions you could ask")
                    }
                    Spacer(minLength: 0)
                    sendOrTalkButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.accent, lineWidth: inputFocused ? 2 : 1.5))
            .shadow(color: Theme.text.opacity(0.08), radius: 12, y: 4)
            .contentShape(Rectangle())
            .onTapGesture { inputFocused = true }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.bg.ignoresSafeArea(edges: .bottom))
        .animation(Springs.slide, value: inputFocused)
        .animation(Springs.slide, value: showingIdeas)
    }

    /// "Questions to try" shows while there are suggestions left, never in exam mode.
    private var offersIdeas: Bool { !session.examMode && !unaskedSuggestions.isEmpty }

    private var sendOrTalkButton: some View {
        let hasText = !draft.trimmingCharacters(in: .whitespaces).isEmpty
        return ZStack {
            // Voice mode off in Settings: the send button stays, greyed until there's text.
            if hasText || !voiceMode {
                Button(action: send) {
                    AppIcon(.arrowUp, size: 22)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassCircle(tint: Theme.accent)
                }
                .accessibilityLabel("Send")
                .disabled(session.isPatientTyping || !hasText)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                // Liquid Glass with a light green tint: the quieter twin of the solid send button.
                Button(action: startVoice) {
                    AppIcon(.mic, size: 22)
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 44, height: 44)
                        .glassFill(Theme.accent, in: Circle(), strength: 0.16)
                }
                .accessibilityLabel("Talk to \(c.firstName)")
                .disabled(session.isPatientTyping)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(Springs.pop, value: hasText)   // both swap at once: fast replace
    }

    // MARK: Voice

    private func startVoice() {
        inputFocused = false
        Task {
            // Live first; if it can't start (allowance used up, no connection), turn-by-turn voice.
            if let live, await live.begin() { return }
            await voice.begin()
        }
    }

    private var isVoiceActive: Bool { live?.isActive == true || voice.isActive }
    private var isLive: Bool { live?.isActive == true }
    private var voicePhase: VoiceController.Phase { isLive ? live?.phase ?? .idle : voice.phase }
    private var voiceLevel: CGFloat { isLive ? live?.level ?? 0 : voice.level }

    private func endVoice() {
        live?.end()
        voice.end()
    }

    private func interruptVoice() {
        if isLive { live?.interrupt() } else { voice.interrupt() }
    }

    /// The line under the orb: what's being said, or how to use the panel.
    private var voiceLine: (text: String, spoken: Bool) {
        if isLive, let live {
            // The caption trails the text events, so it can still be catching up after the reply ended.
            if !live.caption.isEmpty { return (live.caption, true) }
            return (voiceHint, false)
        }
        if voice.phase == .listening, !voice.transcript.isEmpty { return (voice.transcript, true) }
        return (voiceHint, false)
    }

    private var voiceStatus: String {
        if isLive, live?.isConnecting == true { return "Connecting to \(c.firstName)…" }
        if isLive, voicePhase == .listening { return "Your turn. Speak to \(c.firstName)." }
        return switch voicePhase {
        case .listening: voice.transcript.isEmpty ? "Your turn. Speak to \(c.firstName)." : "Listening…"
        case .thinking: "\(c.firstName) is thinking…"
        case .patientSpeaking: "\(c.firstName) is answering"
        case .unavailable(let why): why
        case .idle: ""
        }
    }

    private var voiceHint: String {
        if isLive, let live {
            switch live.phase {
            case .listening, .thinking:
                return "Just talk; \(c.firstName) answers when you pause"
            case .patientSpeaking: return "Talk or tap the orb to interrupt"
            default: return " "
            }
        }
        return switch voice.phase {
        case .listening: autoSend ? "Pause to send, or tap the orb" : "Tap the orb to send"
        case .patientSpeaking: "Tap the orb to interrupt"
        default: " "
        }
    }

    private var voicePanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text(voiceStatus)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(voicePhase == .patientSpeaking ? Theme.info : Theme.text)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.15), value: voiceStatus)
                Spacer()
                IconButton(glyph: .x, label: "End voice mode") { endVoice() }
            }

            if case .unavailable = voicePhase {
                EmptyView()
            } else {
                Button { interruptVoice() } label: {
                    VoiceOrb(phase: voicePhase, level: voiceLevel)
                        .frame(width: VOICEPANEL.orbArea, height: VOICEPANEL.orbArea)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(voicePhase == .patientSpeaking ? "Interrupt the patient" : "Send what you said")

                // The countdown ticks with the clock; the caption and status update on their own.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(voiceLine.text)
                        .font(.system(size: voiceLine.spoken ? 16 : 13))
                        .foregroundStyle(voiceLine.spoken ? Theme.text : Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1) }
    }

    /// Hide a suggestion once its topic is revealed, whatever wording uncovered it.
    private var unaskedSuggestions: [String] {
        let asked = Set(session.messages.filter { $0.kind == .doctor }.map(\.text))
        return c.suggestedQuestions
            .filter { !session.revealed.contains($0.fact) && !asked.contains($0.text) }
            .map(\.text)
    }

    private func send() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        draft = ""
        session.ask(text)
    }

    // MARK: Steps

    private var stepBar: some View {
        let asked = session.messages.filter { $0.kind == .doctor }.count
        let history = session.historyCoverage
        let exam = session.examDone
        let tests = session.testsTaken
        // Exam mode hides coverage, so Ask counts questions instead of key facts.
        let coverage = !session.examMode && showCoverage
        let steps = [
            CaseStepBar.Step(step: .ask, label: "Ask", glyph: .messageSquare,
                             progress: coverage ? "\(history.got)/\(history.total)" : "\(asked)",
                             spokenProgress: coverage ? "\(history.got) of \(history.total) key history found" : "\(asked) questions asked"),
            CaseStepBar.Step(step: .examine, label: "Examine", glyph: .stethoscope,
                             progress: "\(exam.done)/\(exam.total)", spokenProgress: "\(exam.done) of \(exam.total) done"),
            CaseStepBar.Step(step: .tests, label: "Tests", glyph: .flask,
                             progress: session.menuReady ? "\(tests.done)/\(tests.total)" : nil,
                             spokenProgress: session.menuReady ? "\(tests.done) of \(tests.total) taken" : nil),
        ]
        return CaseStepBar(steps: steps, current: tab,
                           hint: stepHint,
                           readyToDiagnose: session.hasWorkedUp,
                           select: { step in withAnimation(Springs.slide) { tab = step } },
                           diagnose: { router.go(.diagnosis) })
    }

    /// The exam grouped the way it's done: general look, vitals, then head to toe.
    private var examine: some View {
        let progress = session.examDone
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CountProgressCard(title: "Examined", done: progress.done, total: progress.total, accessibilityNoun: "examined")
                ForEach(ExamRegion.grouped(c.exam), id: \.region) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(group.region.label)
                        VStack(spacing: 0) {
                            ForEach(Array(group.maneuvers.enumerated()), id: \.element.id) { i, m in
                                if i > 0 { Hairline() }
                                examRow(m)
                            }
                        }
                        .listSurface()
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private func examRow(_ m: ExamManeuver) -> some View {
        let done = session.examined.contains(m.id)
        return Button { session.examine(m.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title).font(.system(size: 16, weight: .medium))
                    Spacer()
                    ZStack {
                        if done {
                            AppIcon(.circleCheck, size: 22)
                                .foregroundStyle(Theme.accent)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else {
                            // Visible action so the row reads as a button, not a checklist. Glass like every
                            // button; not interactive, since the whole row is what's pressed.
                            Text("Examine")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 32)
                                .glassFill(Theme.accentFill, in: Capsule(), interactive: false)
                                .transition(.opacity)
                        }
                    }
                    .animation(Springs.pop, value: done)
                }
                if done {
                    Text(session.findings[m.id] ?? "Examining…")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.dim)
                        .lineSpacing(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(done)
        .accessibilityLabel(done ? "\(m.title), examined. \(session.findings[m.id] ?? "Examining")" : "Examine: \(m.title)")
    }
}
