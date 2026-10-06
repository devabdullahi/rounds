import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Patient deck (Home discovery)
 *
 * DRAG
 *   live   top card follows the finger, tilts 1° per 20pt
 *   live   "TAKE" stamp (green) fades in dragging right,
 *          "SKIP" stamp (red) fades in dragging left
 *   live   card behind grows toward full size as the top one leaves
 *   cross  selection haptic when the drag passes the commit point
 *
 * RELEASE
 *   past 110pt or a fast flick → card flies off that side (spring)
 *   right  take the patient (opens the case)
 *   left   card leaves the deck for good (skipped); the next one rises
 *   short  springs back to centre
 *
 * BUTTONS  (skip ⟵ · random (dice) · ⟶ take) — Liquid Glass on iOS 26+,
 *          interactive: they flex and shimmer under the finger
 *   skip / take    same fly-off as a swipe
 *   random         deck riffles (3 quick shuffles, 90ms apart),
 *                  lands on a random patient, then takes it
 *
 * Reduce Motion: no tilt or riffle; cards cross-fade.
 * ───────────────────────────────────────────────────────── */

private enum SWIPE {
    static let commit: CGFloat = 110          // pt to commit a swipe
    static let flick: CGFloat = 600           // predicted end distance that also commits
    static let tiltPer: Double = 1.0 / 20     // ° of tilt per pt dragged
    static let flyDistance: CGFloat = 560
    static let fly = Animation.spring(response: 0.38, dampingFraction: 0.85)
    static let snapBack = Animation.spring(response: 0.35, dampingFraction: 0.7)
}

enum STACK {
    static let visible = 3
    static let depthOffset: CGFloat = 14      // pt each card peeks out below the one above
    static let depthScale: CGFloat = 0.05
    static let cardHeight: CGFloat = 436      // one big card owns the screen (Avec-style focus)
    static let restack = Animation.spring(response: 0.45, dampingFraction: 0.82)
}

private enum RIFFLE {
    static let shuffles = 3
    static let interval = 0.09                // s between shuffles
    static let settle = 0.35                  // s on the chosen card before it's taken
}

// MOCK (disabled): placeholder incoming patients, replaced by the student's generated ward.
// // MARK: - Model
//
// /// A patient waiting on the ward. Placeholder data for the screens-only phase.
// struct IncomingPatient: Identifiable, Equatable {
//     let id: String              // bed, e.g. "B4"
//     let meta: String            // "M · 54 · chest pain"
//     let quote: String
//     let hr: Int
//     let bp: String
//     let spo2: Int
//     let stElevation: Bool
//     let rotation: Clerkship
//     let system: OrganSystem
//     var hasCase: Bool { id == "B4" }
// }
//
// extension Ward {
//     /// Patients on the ward that fit a focus. Drives the counts in the focus pickers.
//     static func count(for focus: StudyFocus) -> Int {
//         incoming.filter { focus.matches(rotation: $0.rotation, system: $0.system) }.count
//     }
//
//     static func count(for selection: FocusSelection) -> Int {
//         incoming.filter { selection.matches(rotation: $0.rotation, system: $0.system) }.count
//     }
//
//     static let incoming: [IncomingPatient] = [
//         IncomingPatient(id: "B4", meta: "M · 54 · chest pain", quote: "My chest has been hurting since this morning.",
//                         hr: 104, bp: "148/92", spo2: 95, stElevation: true, rotation: .internalMedicine, system: .cardiovascular),
//         IncomingPatient(id: "B7", meta: "F · 31 · palpitations", quote: "My heart keeps racing.",
//                         hr: 148, bp: "118/76", spo2: 98, stElevation: false, rotation: .internalMedicine, system: .cardiovascular),
//         IncomingPatient(id: "B9", meta: "M · 67 · dyspnea", quote: "I get breathless on stairs.",
//                         hr: 96, bp: "152/88", spo2: 91, stElevation: false, rotation: .internalMedicine, system: .respiratory),
//         IncomingPatient(id: "R4", meta: "M · 24 · wheeze", quote: "I can't stop wheezing.",
//                         hr: 118, bp: "128/80", spo2: 93, stElevation: false, rotation: .familyMedicine, system: .respiratory),
//         IncomingPatient(id: "A3", meta: "F · 19 · abdominal pain", quote: "The pain moved to my right side.",
//                         hr: 102, bp: "110/70", spo2: 99, stElevation: false, rotation: .surgery, system: .gastrointestinal),
//         IncomingPatient(id: "N2", meta: "F · 45 · headache", quote: "Worst headache of my life.",
//                         hr: 88, bp: "172/98", spo2: 98, stElevation: false, rotation: .neurology, system: .nervous),
//     ]
// }

// MARK: - Deck

struct PatientDeck: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Home's entrance stage, so the top card's vitals/quote/button still choreograph in.
    var stage: Int

    @State private var queue: [WardPatient] = []
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var drag: CGSize = .zero
    @State private var pastCommit = false
    @State private var busy = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Cards and the admit card are separate layers, not an if/else: swapping branches
                // would fade the whole deck, pulling a swiped-off last card back into view.
                ForEach(Array(queue.prefix(STACK.visible).enumerated()).reversed(), id: \.element.id) { depth, p in
                    card(p, depth: depth)
                }
                // Also covers the deck while a patient is being written, so the shuffle button's
                // "admit a new patient" shows progress even with others waiting.
                if queue.isEmpty || app.isAdmitting {
                    AdmitCard(admitting: app.isAdmitting, preparing: app.isPreparingCondition,
                              loading: app.isLoadingWard && app.ward.isEmpty) { admit() }
                        .zIndex(Double(STACK.visible + 1))
                        .transition(.opacity)
                }
            }
            .padding(.bottom, STACK.depthOffset * CGFloat(STACK.visible - 1))

            // The row sits fully above the tab bar's fade, so the red and green buttons aren't
            // darkened at the bottom while the smaller shuffle button escapes it.
            controls
                .accessibilityHint("\(queue.count) waiting. Swipe right to take, left to skip.")
        }
        .sensoryFeedback(.selection, trigger: pastCommit)
        .onAppear { syncQueue() }
        .onChange(of: app.ward) { withAnimation(STACK.restack) { syncQueue() } }
        .onChange(of: focusStored) { withAnimation(STACK.restack) { putFocusFirst() } }
        #if DEBUG
        .task {
            switch DebugLaunch.screen {
            case "home-swipe-right": drag = CGSize(width: 120, height: 6)
            case "home-swipe-left": drag = CGSize(width: -120, height: 6)
            default: break
            }
        }
        #endif
    }

    // MARK: Card

    private func card(_ p: WardPatient, depth: Int) -> some View {
        let isTop = depth == 0
        // Cards behind grow toward the front as the top one is dragged away.
        let progress = isTop ? 0 : min(1, abs(drag.width) / SWIPE.commit)
        let effectiveDepth = CGFloat(depth) - (depth == 1 ? progress : 0)
        let dx = isTop ? drag.width : 0

        return PatientCard(patient: p, stage: isTop ? stage : 6, revisit: p.status == .revisit,
                           opening: app.openingBed == p.id,
                           dragging: isTop && drag != .zero, onTake: { take() })
            .overlay(alignment: .top) { if isTop { stamps } }
            .scaleEffect(1 - effectiveDepth * STACK.depthScale, anchor: .bottom)
            .offset(y: effectiveDepth * STACK.depthOffset)
            .offset(x: dx, y: isTop ? drag.height * 0.15 : 0)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(dx) * SWIPE.tiltPer), anchor: .bottom)
            .allowsHitTesting(isTop)
            .zIndex(Double(STACK.visible - depth))
            .gesture(isTop ? dragGesture : nil)
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
            .accessibilityHidden(!isTop)
            .accessibilityAction(named: "Take patient") { take() }
            .accessibilityAction(named: "Skip patient") { skip() }
    }

    /// TAKE / SKIP stamps that fade in with the drag.
    private var stamps: some View {
        let right = max(0, min(1, drag.width / SWIPE.commit))
        let left = max(0, min(1, -drag.width / SWIPE.commit))
        return HStack {
            stamp("TAKE", color: Theme.correct, angle: -12).opacity(right)
            Spacer()
            stamp("SKIP", color: Theme.streak, angle: 12).opacity(left)
        }
        .padding(22)
        .padding(.top, 34)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3))
            .background(Theme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .rotationEffect(.degrees(angle))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard !busy, abs(v.translation.width) > abs(v.translation.height) || drag != .zero else { return }
                drag = v.translation
                let past = abs(v.translation.width) > SWIPE.commit
                if past != pastCommit { pastCommit = past }
            }
            .onEnded { v in
                guard !busy, drag != .zero else { return }
                let w = v.predictedEndTranslation.width
                if drag.width > SWIPE.commit || w > SWIPE.flick { take() }
                else if drag.width < -SWIPE.commit || w < -SWIPE.flick { skip() }
                else { withAnimation(SWIPE.snapBack) { drag = .zero } }
                pastCommit = false
            }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 28) {
            // Skip and take need a patient; with an empty ward only the dice (admit) works.
            roundButton(.x, label: "Skip patient", tint: Theme.streak, size: 60, enabled: !queue.isEmpty) { skip() }
            roundButton(.dice, label: queue.count > 1 ? "Random patient" : "Admit a new patient", tint: Theme.shuffle, size: 50) { random() }
            roundButton(.check, label: "Take patient", tint: Theme.correct, size: 60, enabled: !queue.isEmpty) { take() }
        }
        .frame(maxWidth: .infinity)
        .disabled(busy || app.isAdmitting)
    }

    private func roundButton(_ glyph: IconGlyph, label: String, tint: Color, size: CGFloat, enabled: Bool = true,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppIcon(glyph, size: size * 0.42)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .glassCircle(tint: tint)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.2), value: enabled)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    /// Right: the top patient is taken and their case opens.
    private func take() {
        guard !busy, let p = queue.first else { return }
        busy = true
        withAnimation(SWIPE.fly) { drag = CGSize(width: SWIPE.flyDistance, height: 0) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            await app.open(bed: p.id)
            try? await Task.sleep(for: .seconds(0.4))   // card returns behind the case sheet
            withAnimation(SWIPE.snapBack) { drag = .zero }
            busy = false
        }
    }

    /// Generates a new patient in the student's focus; it opens when ready.
    private func admit() {
        Task { await app.admit(focus: FocusSelection(stored: focusStored)) }
    }

    /// Waiting patients, focus first, keeping the student's current order for ones already shown.
    private func syncQueue() {
        let waiting = app.waiting
        let kept = queue.compactMap { q in waiting.first { $0.id == q.id } }
        queue = waiting.filter { w in !kept.contains { $0.id == w.id } } + kept
        putFocusFirst()
    }

    /// Left: the top patient goes to the back of the list.
    /// Matching patients move to the front, in their current order; the rest follow.
    private func putFocusFirst() {
        let focus = FocusSelection(stored: focusStored)
        queue = queue.filter { $0.fits(focus) } + queue.filter { !$0.fits(focus) }
    }

    /// Left: the top patient leaves the deck for good. They stay on the Patients tab.
    /// Skipping the last one leaves the admit card.
    private func skip() {
        guard !busy, let p = queue.first else { withAnimation(SWIPE.snapBack) { drag = .zero }; return }
        busy = true
        withAnimation(SWIPE.fly) { drag = CGSize(width: -SWIPE.flyDistance, height: 0) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.28))
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { drag = .zero }
            // Same render pass: the leaver (already off-screen) vanishes via its .identity removal
            // while the cards behind spring up a place.
            withAnimation(STACK.restack) { _ = queue.removeFirst() }
            app.skip(bed: p.id)
            busy = false
        }
    }

    /// Riffle the deck a few times, land on a random patient, then take it.
    /// With one patient or none waiting, admits a new one instead.
    private func random() {
        guard queue.count > 1 else { admit(); return }
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            if !reduceMotion {
                for _ in 0..<RIFFLE.shuffles {
                    withAnimation(STACK.restack) { queue.append(queue.removeFirst()) }
                    try? await Task.sleep(for: .seconds(RIFFLE.interval))
                }
            }
            let pick = Int.random(in: 0..<queue.count)
            withAnimation(STACK.restack) { queue.insert(queue.remove(at: pick), at: 0) }
            try? await Task.sleep(for: .seconds(RIFFLE.settle))
            busy = false
            take()
        }
    }
}

// MARK: - Card

/// The incoming-patient card, for any patient on the ward.
struct PatientCard: View {
    let patient: WardPatient
    var stage: Int = 6
    var revisit = false
    /// The case is being fetched after a take.
    var opening = false
    /// While the card is being swiped, its button ignores touches entirely.
    var dragging = false
    var onTake: () -> Void

    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    private enum VITALS {
        static let stagger = 0.08
        static let offsetY: CGFloat = 8
        static let spring = Springs.pop
        static let hrJitter = [0, 0, 1, 0, -1, 0, 1]   // monitor flicker, one step per second
        static let beatGlow: CGFloat = 3
        static let beatScale: CGFloat = 0.04
        static let beatDecay = 0.14
    }

    /// The tag the focus didn't already cover: the system when the rotation matched, else the rotation.
    private var otherTag: String? {
        if let r = patient.rotation, focus.contains(.rotation(r)) { return patient.system?.label }
        return patient.rotation?.label
    }

    private var heartRate: Int {
        #if DEBUG
        if let override = DebugLaunch.heartRate { return override }
        #endif
        return patient.hr ?? 80
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Who: avatar + bed/meta, status on the right
            HStack(spacing: 14) {
                Text(patient.id)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(revisit ? "Revisit" : "Incoming").font(.system(size: 17, weight: .semibold))
                    Text(patient.meta).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    GlowDot(color: revisit ? Theme.info : Theme.warn, pulsing: !revisit)
                    Text(revisit ? "Retry" : "Waiting").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(revisit ? Theme.info : Theme.warn)
            }

            // Where it fits. A patient in the student's focus says so once, instead of
            // repeating the focus name that already sits above the deck.
            HStack(spacing: 6) {
                if !focus.isMix, patient.fits(focus) {
                    Pill(text: "Your focus", glyph: .target)
                    // Name whichever tag the focus didn't already cover.
                    if let other = otherTag {
                        Pill(text: other, fg: Theme.muted, bg: Theme.text.opacity(0.07))
                    }
                } else {
                    ForEach([patient.rotation?.label, patient.system?.label].compactMap { $0 }, id: \.self) { tag in
                        Pill(text: tag, fg: Theme.muted, bg: Theme.text.opacity(0.07))
                    }
                }
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 16)

            // What they say: the hero of the card
            Text("\u{201C}\(patient.quote)\u{201D}")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .lineSpacing(4)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(stage >= 3 ? 1 : 0)
                .offset(y: stage >= 3 ? 0 : VITALS.offsetY)
                .animation(Springs.slide, value: stage)

            Spacer(minLength: 20)

            // Monitor
            VStack(alignment: .leading, spacing: 12) {
                vitals
                ECGMonitor(bpm: Double(heartRate), stElevation: false)
                    .opacity(stage >= 2 ? 1 : 0)
            }

            Spacer(minLength: 24)

            Button(opening ? "Opening…" : revisit ? "Retry the patient" : "Take the patient", action: onTake)
                .buttonStyle(PrimaryButtonStyle(height: 54, reactive: false))   // static: never swells, even mid-swipe
                .allowsHitTesting(!dragging)
                .opacity(stage >= 4 ? 1 : 0)
                .scaleEffect(stage >= 4 ? 1 : 0.96)
                .animation(Springs.pop, value: stage)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: STACK.cardHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 24, y: 10)
    }

    private var vitals: some View {
        let items: [(String, Color, CGFloat)] = [("HR", Theme.accent, 34), ("BP", Theme.warn, 22), ("SpO₂", Theme.info, 34)]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.0).font(.system(size: 12)).foregroundStyle(item.1)
                    Group {
                        switch item.0 {
                        case "HR":
                            TimelineView(.animation) { ctx in
                                let tick = Int(ctx.date.timeIntervalSinceReferenceDate) % VITALS.hrJitter.count
                                let pulse = CGFloat(exp(-ECG.timeSinceBeat(at: ctx.date, bpm: Double(heartRate)) / VITALS.beatDecay))
                                Text("\(heartRate + VITALS.hrJitter[tick])")
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: tick)
                                    .scaleEffect(1 + VITALS.beatScale * pulse, anchor: .leading)
                                    .shadow(color: Theme.glow(Theme.accent, 0.45 + 0.35 * Double(pulse)),
                                            radius: 7 + VITALS.beatGlow * pulse)
                            }
                        case "BP": Text(patient.bp ?? "–").padding(.top, 8)
                        default: Text(patient.spo2.map(String.init) ?? "–")
                        }
                    }
                    .font(.mono(item.2))
                    .foregroundStyle(item.1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(stage >= 2 ? 1 : 0)
                .offset(y: stage >= 2 ? 0 : VITALS.offsetY)
                .animation(VITALS.spring.delay(Double(i) * VITALS.stagger), value: stage)
            }
        }
    }
}
