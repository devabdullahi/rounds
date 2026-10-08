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

private enum DOTS {
    static let stagger = 0.15               // s between dot bounces
    static let lift: CGFloat = 4            // px each dot hops
    static let period = 0.9                 // s per bounce cycle
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

    @State private var tab: InterviewTab = .history
    @State private var showingFindings = false
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    @State private var voice = VoiceController()

    private var c: ClinicalCase { session.clinical }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // The patient on the monitor while you talk. It steps aside while typing, when the
            // keyboard leaves the chat little room.
            if tab == .history && !inputFocused {
                PatientMonitor(vitals: c.vitals)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Group {
                switch tab {
                case .history: chat
                case .examine: examine
                }
            }
            .frame(maxHeight: .infinity)
            if tab == .examine {
                Button("I'm ready to diagnose") { router.go(.diagnosis) }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            } else if voice.isActive {
                voicePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                composer
                    .transition(.opacity)   // pops out at once so the panel isn't waiting on it
            }
        }
        .animation(VOICEPANEL.spring, value: voice.isActive)
        .animation(MONITOR.spring, value: inputFocused)
        .background(Theme.bg)
        .onDisappear { voice.end() }
        .onChange(of: session.messages.count) {
            // Patient answered while we're in voice mode: say it out loud.
            guard voice.phase == .thinking,
                  let reply = session.messages.last(where: { $0.kind == .patient }) else { return }
            voice.speak(reply.text)
        }
        .onAppear {
            voice.onUtterance = { [session] text in session.ask(text) }
            session.startClockIfNeeded()
            tab = .history
            #if DEBUG
            if DebugLaunch.screen == "examine" { tab = .examine }
            if DebugLaunch.screen == "interview-exam" || DebugLaunch.screen == "interview-exam-chat" { session.examMode = true }
            if ["interview-chat", "interview-exam-chat", "interview-findings"].contains(DebugLaunch.screen) { session.debugSeedChat() }
            if DebugLaunch.screen == "interview-findings" {
                Task { try? await Task.sleep(for: .seconds(1)); showingFindings = true }
            }
            if DebugLaunch.screen == "voice-listen" { voice.debugPin(.listening, level: 0.75, transcript: "Any sweating or feeling sick?") }
            if DebugLaunch.screen == "voice-patient" { voice.debugPin(.patientSpeaking, level: 0.5) }
            #endif
        }
        .onChange(of: tab) { _, new in
            if new != .history { voice.end() }
        }
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
                        Text("\(c.name), \(c.age)").font(.system(size: 17, weight: .semibold))
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
            HStack(spacing: 8) {
                Segmented(options: [(InterviewTab.history, "History"), (.examine, "Examine")], selection: $tab)
                // Tests open their own screen, so they're a way forward, not a third tab.
                Button { router.go(.workup) } label: {
                    HStack(spacing: 4) {
                        Text("Tests")
                        AppIcon(.arrowRight, size: 14)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Theme.accentSoft, in: Capsule())
                }
                .buttonStyle(PressDownStyle())
                .accessibilityHint("Opens tests to order")
            }
            .padding(.horizontal, 8)
            Group {
                if session.examMode { questionCount } else { coverageMeter }
            }
            .padding(.horizontal, 8)
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
                                              : "Introduce yourself, then take a focused history. Type or tap a suggestion.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                    }
                    ForEach(session.messages) { m in
                        bubble(m).id(m.id)
                    }
                    if session.isPatientTyping {
                        TypingDots()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .offset(y: BUBBLE.offsetY)))
                            .id("typing")
                    }
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
        }
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
            Pill(text: m.text, glyph: .check)
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: REVEAL.initialScale).combined(with: .opacity).animation(Springs.pop))
        case .problem:
            // A failed request: say what went wrong so the student can resend.
            Pill(text: m.text, fg: Theme.warnText, bg: Theme.warn.opacity(0.12), glyph: .circleX)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            // Exam mode is unassisted: no suggested questions.
            if !session.examMode && (!inputFocused || draft.isEmpty) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(unaskedSuggestions, id: \.self) { s in
                            // Outlined, not filled: a fallback when stuck, quieter than the student's own question.
                            Button(s) { session.ask(s) }
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.accentText)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Theme.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5)))
                                .buttonStyle(.plain)
                                .disabled(session.isPatientTyping)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .trailingFade()
                .transition(.opacity)
            }
            HStack(spacing: 8) {
                TextField("", text: $draft, prompt: Text("Ask the patient…").foregroundStyle(Theme.faint))
                    .font(.system(size: 16))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Theme.bg, in: Capsule())
                    .overlay(Capsule().strokeBorder(inputFocused ? Theme.accent : Theme.border))
                    .accessibilityLabel("Ask the patient")
                let hasText = !draft.trimmingCharacters(in: .whitespaces).isEmpty
                ZStack {
                    if hasText {
                        Button(action: send) {
                            AppIcon(.arrowUp, size: 22)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .glassCircle(tint: Theme.accent)
                        }
                        .accessibilityLabel("Send")
                        .disabled(session.isPatientTyping)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        Button(action: startVoice) {
                            AppIcon(.mic, size: 22)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .glassCircle(tint: Theme.accent)
                        }
                        .accessibilityLabel("Talk to the patient")
                        .disabled(session.isPatientTyping)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(Springs.pop, value: hasText)   // both swap at once: fast replace
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1) }
        .animation(Springs.slide, value: inputFocused)
    }

    // MARK: Voice

    private func startVoice() {
        inputFocused = false
        Task { await voice.begin() }
    }

    private var voiceStatus: String {
        switch voice.phase {
        case .listening: voice.transcript.isEmpty ? "Your turn. Speak to \(c.name.split(separator: " ").first ?? "")." : "Listening…"
        case .thinking: "\(c.name.split(separator: " ").first ?? "") is thinking…"
        case .patientSpeaking: "\(c.name.split(separator: " ").first ?? "") is answering"
        case .unavailable(let why): why
        case .idle: ""
        }
    }

    private var voiceHint: String {
        switch voice.phase {
        case .listening: "Pause to send, or tap the orb"
        case .patientSpeaking: "Tap the orb to interrupt"
        default: " "
        }
    }

    private var voicePanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text(voiceStatus)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(voice.phase == .patientSpeaking ? Theme.info : Theme.text)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.15), value: voiceStatus)
                Spacer()
                IconButton(glyph: .x, label: "End voice mode") { voice.end() }
            }

            if case .unavailable = voice.phase {
                EmptyView()
            } else {
                Button { voice.interrupt() } label: {
                    VoiceOrb(phase: voice.phase, level: voice.level)
                        .frame(width: VOICEPANEL.orbArea, height: VOICEPANEL.orbArea)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(voice.phase == .patientSpeaking ? "Interrupt the patient" : "Send what you said")

                Text(voice.phase == .listening && !voice.transcript.isEmpty ? voice.transcript : voiceHint)
                    .font(.system(size: voice.transcript.isEmpty || voice.phase != .listening ? 13 : 16))
                    .foregroundStyle(voice.phase == .listening && !voice.transcript.isEmpty ? Theme.text : Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40)
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

    // MARK: Examine

    private var examine: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(Array(c.exam.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Hairline() }
                        examRow(m)
                    }
                }
                .listSurface()

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
                            // Visible action so the row reads as a button, not a checklist.
                            // Soft, not saturated: six rows of bright buttons drowned out the findings.
                            Text("Examine")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accentText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(Theme.accentSoft, in: Capsule())
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

private struct TypingDots: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t - Double(i) * DOTS.stagger).truncatingRemainder(dividingBy: DOTS.period) / DOTS.period
                    Circle()
                        .fill(Theme.faint)
                        .frame(width: 7, height: 7)
                        .offset(y: -DOTS.lift * max(0, sin(phase * .pi * 2)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityLabel("Patient is answering")
    }
}
