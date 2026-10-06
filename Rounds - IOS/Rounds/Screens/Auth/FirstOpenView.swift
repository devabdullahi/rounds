import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Welcome (differential narrowing)
 *
 * Every signed-out launch. Light mode. Two states: welcome, then the sign-up sheet.
 *
 * Intro
 *    0ms   heart trace draws left → right (1400ms, ease in-out)
 *  300ms   headline rises, y 12 → 0
 *  500ms   "Let's go" rises
 *
 * Differential loop (one case at a time, forever)
 *    0ms   case summary fades up ("54 · chest pain · sweating · HR 104")
 *  200ms   six diagnosis bubbles jump toward the screen, 160ms apart: scale 0.4 → 1,
 *          blur 8 → 0, slow spring with a little overshoot (PS Vita home screen)
 *  always  each bubble floats: bobs 3pt and breathes ±4% toward the viewer, its own
 *          3–4s period and phase, shadow deepening as it comes closer
 * 2100ms   wrong chips cross out one by one, 350ms apart; each fades to 38%
 *  +500ms  the answer turns green, grows 1.12×, check slides in
 *  +2.4s   hold, then everything fades out (350ms) and the next case starts
 *
 * "Let's go" tapped: headline + button fade; sheet springs up over a scrim.
 * Tap the scrim or drag the sheet's handle down: back to welcome.
 * Reduce Motion: first case shown solved, no loop, no trace draw.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let headline = 0.30   // headline rises
    static let cta      = 0.50   // "Let's go" rises
}

private enum TRACE {
    static let duration = 1.4
    static let curve = Animation.timingCurve(0.65, 0, 0.35, 1, duration: duration)
    static let height: CGFloat = 48
    static let lineWidth: CGFloat = 2
}

private enum LOOP {
    static let summaryLead = 0.2     // s before chips start popping in
    static let chipStagger = 0.16    // s between bubbles jumping in
    static let firstStrike = 1.9     // s after bubbles start
    static let strikeGap = 0.35      // s between strikes
    static let pickDelay = 0.5       // s after the last strike
    static let hold = 2.4            // s the solved case stays up
    static let fadeOut = 0.35
    static let pop = Animation.spring(response: 0.9, dampingFraction: 0.62)   // slow jump, soft overshoot
    static let strike = Animation.easeOut(duration: 0.3)
    static let pick = Animation.spring(response: 0.4, dampingFraction: 0.62)
}

/// PS Vita-style floating: depth comes from scale and shadow, not position.
private enum FLOAT {
    static let basePeriod = 3.2      // s per bob for the first bubble
    static let periodStep = 0.27     // each bubble a little slower, so they never sync
    static let bob: CGFloat = 3      // pt up and down
    static let breathe: CGFloat = 0.04   // ±4% toward / away from the viewer
    static let enterScale: CGFloat = 0.4
    static let enterBlur: CGFloat = 8
}

private enum SHEET {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let dismissDrag: CGFloat = 90
}

/// Darker than the app accent so white button text clears 4.5:1 on the light welcome.
private let welcomeGreen = Color(hex: 0x027A46)

/// One teaching case: a summary, five wrong answers, one right one.
private struct DifferentialCase {
    let summary: String
    let wrong: [String]
    let answer: String
}

private let cases: [DifferentialCase] = [
    DifferentialCase(summary: "54 · chest pain · sweating · HR 104",
                     wrong: ["Pulmonary embolism", "Aortic dissection", "Pericarditis", "GERD", "Panic attack"],
                     answer: "STEMI"),
    DifferentialCase(summary: "45 · worst headache of her life",
                     wrong: ["Migraine", "Meningitis", "Tension headache", "Sinusitis", "Cluster headache"],
                     answer: "Subarachnoid bleed"),
    DifferentialCase(summary: "19 · pain moved to the right side · fever",
                     wrong: ["Gastroenteritis", "Ovarian cyst", "Kidney stone", "UTI", "Constipation"],
                     answer: "Appendicitis"),
]

/// Where each wrong chip sits: leading or trailing edge, inset, and y. Scattered, never overlapping.
private let slots: [(trailing: Bool, inset: CGFloat, y: CGFloat)] = [
    (false, 6, 56), (true, 0, 112), (false, 24, 174), (true, 18, 262), (false, 0, 318),
]
private let answerY: CGFloat = 218

struct FirstOpenView: View {
    var onSignUp: () -> Void
    var onLogIn: () -> Void
    var onSocial: (SocialProvider) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var shown = false
    @State private var showAuth = false
    @State private var sheetDrag: CGFloat = 0

    // Differential loop state
    @State private var caseIndex = 0
    @State private var visible = false        // summary on screen
    @State private var popped = 0             // chips popped in so far (wrong chips, then the answer)
    @State private var struck = 0             // wrong chips crossed out so far
    @State private var picked = false

    private var current: DifferentialCase { cases[caseIndex] }

    var body: some View {
        ZStack(alignment: .bottom) {
            welcome

            if showAuth {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                    .zIndex(1)
                authSheet
                    .offset(y: max(0, sheetDrag))
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .background { GlowBackdrop() }
        #if DEBUG
        .devSkip()
        .onAppear { if DebugLaunch.screen == "firstopen-auth" { showAuth = true } }
        #endif
        .onAppear(perform: playIntro)
        .task { await runLoop() }
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AppIcon(.brandMark, size: 20).foregroundStyle(Theme.accent)
                Text("Welcome to Rounds").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            differential
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)

            ECGMarks.wide
                .trim(from: 0, to: drawn)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: TRACE.lineWidth, lineCap: .round, lineJoin: .round))
                .frame(height: TRACE.height)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 26) {
                Text("Practice the hard\ncalls before\nthey're real.")
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1)
                    .lineSpacing(-4)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .rise(shown && !showAuth, at: showAuth ? 0 : TIMING.headline)

                Button("Let's go") { open() }
                    .buttonStyle(PrimaryButtonStyle(height: 54, tint: welcomeGreen))
                    .rise(shown && !showAuth, at: showAuth ? 0 : TIMING.cta)
                    .allowsHitTesting(!showAuth)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    /// Diagnosis chips get crossed out until one answer is left: the reasoning Rounds trains.
    private var differential: some View {
        ZStack(alignment: .top) {
            Text(current.summary)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 8)

            ForEach(Array(current.wrong.enumerated()), id: \.offset) { i, label in
                let slot = slots[i]
                DiagnosisChip(label: label, struck: struck > i)
                    .modifier(VitaFloat(index: i, active: !reduceMotion))
                    .modifier(JumpIn(isIn: popped > i))
                    .frame(maxWidth: .infinity, alignment: slot.trailing ? .trailing : .leading)
                    .padding(slot.trailing ? .trailing : .leading, slot.inset)
                    .offset(y: slot.y)
            }

            AnswerChip(label: current.answer, picked: picked)
                .modifier(VitaFloat(index: current.wrong.count, active: !reduceMotion))
                .modifier(JumpIn(isIn: popped > current.wrong.count))
                .offset(y: answerY)
        }
        .frame(height: 370, alignment: .top)
        .id(caseIndex)   // a new case is a fresh set of chips, never a morph of the old one
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example case: \(current.summary). Answer: \(current.answer).")
    }

    // MARK: Sheet

    private var authSheet: some View {
        VStack(spacing: 12) {
            // Handle strip: the only drag target, so it never competes with the buttons.
            Capsule().fill(Theme.text.opacity(0.15)).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
                .gesture(dragToClose)

            Button("Sign up", action: onSignUp)
                .buttonStyle(PrimaryButtonStyle(height: 54, tint: welcomeGreen))

            Button(action: onLogIn) {
                Text("Log in").frame(maxWidth: .infinity, minHeight: 54)
            }
            .modifier(OutlineCapsule())

            OrDivider(text: "or").padding(.vertical, 4)

            Button { onSocial(.apple) } label: {
                providerLabel("Continue with Apple") {
                    Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium)).offset(y: -1)
                }
            }
            .modifier(OutlineCapsule())

            Button { onSocial(.google) } label: {
                providerLabel("Continue with Google") { GoogleLogo(size: 18) }
            }
            .modifier(OutlineCapsule())

            Text("For practice only. Fictional patients, not medical advice.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.10), radius: 30, y: -10)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Provider rows share one icon column on the leading edge; the label stays centered.
    private func providerLabel<Icon: View>(_ title: String, @ViewBuilder icon: () -> Icon) -> some View {
        ZStack {
            HStack { icon().frame(width: 22, height: 22); Spacer() }.padding(.leading, 20)
            Text(title)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
    }

    private var dragToClose: some Gesture {
        DragGesture()
            .onChanged { sheetDrag = $0.translation.height }
            .onEnded { value in
                if value.translation.height > SHEET.dismissDrag || value.predictedEndTranslation.height > SHEET.dismissDrag * 2 {
                    close()
                } else {
                    withAnimation(SHEET.spring) { sheetDrag = 0 }
                }
            }
    }

    // MARK: Choreography

    private func playIntro() {
        shown = true
        guard !reduceMotion else { drawn = 1; return }
        withAnimation(TRACE.curve) { drawn = 1 }
    }

    /// Runs one case after another until the view goes away (`.task` cancels it).
    private func runLoop() async {
        if reduceMotion {
            visible = true; popped = current.wrong.count + 1; struck = current.wrong.count; picked = true
            return
        }
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.3)) { visible = true }
            guard await pause(LOOP.summaryLead) else { return }

            for _ in 0...current.wrong.count {
                withAnimation(LOOP.pop) { popped += 1 }
                guard await pause(LOOP.chipStagger) else { return }
            }
            guard await pause(LOOP.firstStrike - LOOP.chipStagger * Double(current.wrong.count + 1)) else { return }

            for _ in current.wrong.indices {
                withAnimation(LOOP.strike) { struck += 1 }
                guard await pause(LOOP.strikeGap) else { return }
            }
            guard await pause(LOOP.pickDelay) else { return }
            withAnimation(LOOP.pick) { picked = true }

            guard await pause(LOOP.hold) else { return }
            withAnimation(.easeIn(duration: LOOP.fadeOut)) { visible = false; popped = 0 }
            guard await pause(LOOP.fadeOut) else { return }

            struck = 0
            picked = false
            caseIndex = (caseIndex + 1) % cases.count
        }
    }

    /// Sleeps; false once the task is cancelled, so the loop exits cleanly.
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(max(0, seconds)))
        return !Task.isCancelled
    }

    private func open() {
        withAnimation(SHEET.spring) { showAuth = true }
    }

    private func close() {
        withAnimation(SHEET.spring) {
            showAuth = false
            sheetDrag = 0
        }
    }
}

// MARK: - Chips

/// Arrives from far away: small, blurred and faint, then springs up to full size.
private struct JumpIn: ViewModifier {
    let isIn: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isIn ? 1 : FLOAT.enterScale)
            .blur(radius: isIn ? 0 : FLOAT.enterBlur)
            .opacity(isIn ? 1 : 0)
    }
}

/// Gentle, endless bob and breathe, each bubble on its own period and phase.
private struct VitaFloat: ViewModifier {
    let index: Int
    let active: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !active)) { ctx in
            let period = FLOAT.basePeriod + Double(index) * FLOAT.periodStep
            let phase = Double(index) * 1.3
            let wave = active ? sin(ctx.date.timeIntervalSinceReferenceDate * 2 * .pi / period + phase) : 0
            let near = (wave + 1) / 2   // 0 far, 1 near
            content
                .scaleEffect(1 + FLOAT.breathe * wave)
                .offset(y: -FLOAT.bob * wave)
                .shadow(color: .black.opacity(0.05 + 0.06 * near), radius: 6 + 8 * near, y: 3 + 5 * near)
        }
    }
}

/// A wrong answer: white chip that gets a strike line and fades back.
private struct DiagnosisChip: View {
    let label: String
    let struck: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Theme.muted)
                    .frame(height: 2)
                    .scaleEffect(x: struck ? 1 : 0, anchor: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.surface, in: Capsule())
            .opacity(struck ? 0.38 : 1)
            .fixedSize()
    }
}

/// The right answer: soft green until picked, then filled with a check.
private struct AnswerChip: View {
    let label: String
    let picked: Bool

    var body: some View {
        HStack(spacing: 6) {
            if picked {
                AppIcon(.check, size: 18)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            Text(label)
        }
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(picked ? .white : welcomeGreen)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        // No outline: a soft green wash marks the answer before it's picked.
        .background(picked ? welcomeGreen : Color(hex: 0xE3F5EA), in: Capsule())
        .shadow(color: welcomeGreen.opacity(picked ? 0.3 : 0), radius: 14, y: 8)
        .scaleEffect(picked ? 1.12 : 1)
        .fixedSize()
    }
}

/// Outlined capsule for the secondary sign-up options.
private struct OutlineCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.text)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border))
            .contentShape(Capsule())
            .buttonStyle(PressDownStyle())
    }
}
