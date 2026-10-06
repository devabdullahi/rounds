import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Flashcards
 *
 * DEAL-IN (first time the tab opens per app session; later visits show it in place)
 *    0ms   deck waits below the screen edge, fanned ±10° (solid, no fade)
 *   60ms   back card springs up into the stack
 *  +70ms   each card above it follows (staggered 70ms, chained)
 *  ~350ms  top card lands with a small overshoot, fan closes to 0°
 *  450ms   "Tap to flip" hint fades in
 *  520ms   Correct / I don't know buttons rise, y 20 → 0
 *
 * FLIP (tap the card)
 *    0ms   card turns 180° on Y; front fades at 90°, answer shows
 *
 * VERDICT (tap a button)
 *    0ms   button fills green (Correct) or red (I don't know)
 *    0ms   card edge glows the same colour
 *  220ms   card flies off: right + 14° (Correct) / left − 14° (don't know)
 *  220ms   next card rises from the stack, scale 0.96 → 1.0
 *  420ms   button returns to rest; ready for the next card
 *
 * Reduce Motion: no deal-in or fly-off; cards cross-fade.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let dealStart   = 0.06    // first card launches
    static let dealStagger = 0.07    // between cards
    static let hint        = 0.45
    static let buttons     = 0.52
    static let verdictHold = 0.22    // colour shows before the card leaves
    static let settle      = 0.42    // button back to rest
}

private enum DECK {
    static let visible = 3                     // cards drawn in the stack
    static let depthOffset: CGFloat = 12       // pt each card peeks out below the one above
    static let depthScale: CGFloat = 0.045     // scale lost per depth step
    static let dealFrom: CGFloat = 640         // pt below the stack: starts under the screen edge
    static let fan: Double = 10                // ° spread while dealing
    static let deal = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let cardHeight: CGFloat = 380
}

private enum FLIGHT {
    static let distance: CGFloat = 520
    static let tilt: Double = 14
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

private enum FLIP {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

// MARK: - Card colours

/// The look of each `CardColor`: `tint` drives the wash, border and label; light values are deepened for contrast.
extension CardColor {
    var tint: Color {
        switch self {
        case .standard: Theme.accent
        case .teal:     .adaptive(dark: 0x2DD4BF, light: 0x0F8A7E)
        case .blue:     .adaptive(dark: 0x60A5FA, light: 0x1D5FC2)
        case .purple:   .adaptive(dark: 0xA78BFA, light: 0x6D3FD6)
        case .pink:     .adaptive(dark: 0xF472B6, light: 0xC0307A)
        case .red:      .adaptive(dark: 0xFF5A63, light: 0xE5011A)
        case .yellow:   .adaptive(dark: 0xFACC15, light: 0x9A7400)
        }
    }

    /// Card fill: plain surface for Default, a soft wash of the tint otherwise.
    var wash: Double { self == .standard ? 0 : 0.12 }
}

// MARK: - Screen

/// True after the first deal-in this app session (resets when the app is closed).
private var flashcardsHaveDealt = false

struct FlashcardsView: View {
    private enum Verdict { case correct, unknown }

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [Flashcard] = []
    @State private var known = 0
    @State private var missed = 0
    @State private var flipped = false
    @State private var verdict: Verdict?
    @State private var dealt = flashcardsHaveDealt
    @State private var controlsShown = flashcardsHaveDealt
    @State private var hintShown = flashcardsHaveDealt
    @State private var busy = false
    @State private var composing = false
    @State private var choosingAdd = false
    @State private var generating = false
    @State private var confirmingClear = false
    /// Set by the add sheet; the matching sheet opens once it has closed.
    @State private var pendingAdd: AddCardsSheet.Choice?

    private var store: FlashcardStore { app.flashcards }
    private var total: Int { store.studying.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenTitle(title: "Flashcards") {
                // Only when there's something to clear; an always-disabled menu is clutter.
                if store.mineCount > 0 {
                    Menu {
                        Button(role: .destructive) { confirmingClear = true } label: {
                            Label { Text("Clear all my cards") } icon: { Image(IconGlyph.trash.assetName) }
                        }
                    } label: {
                        AppIcon(.more, size: 20)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassCircle(tint: Theme.faint)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("More options")
                }
                Button { choosingAdd = true } label: {
                    AppIcon(.plus, size: 20)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glassCircle(tint: Theme.accent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressDownStyle())
                .accessibilityLabel("Add cards")
            }

            if store.decks.count > 1 { deckChips }

            if total > 0 { ProgressBar(value: Double(known) / Double(total), height: 4) }

            // Nothing until the first load lands, then: no cards, a finished deck, or the deck.
            // The summary needs answered cards, so an empty queue mid-load never reads "0 / 0".
            if !store.hasLoaded {
                Color.clear.frame(maxHeight: .infinity)
            } else if store.cards.isEmpty {
                emptyState
            } else if queue.isEmpty {
                if known + missed > 0 {
                    summary.transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            } else {
                deck
                Text(flipped ? "How did you do?" : "Tap the card to flip")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)
                    .opacity(hintShown ? 1 : 0)
                buttons
                    .opacity(controlsShown ? 1 : 0)
                    .offset(y: controlsShown ? 0 : 20)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .clipped()   // cards rise from the bottom edge, never over the tab bar
        .sheet(isPresented: $choosingAdd, onDismiss: openPendingAdd) {
            AddCardsSheet { pendingAdd = $0 }
        }
        .sheet(isPresented: $composing) {
            NewCardSheet { card in
                Task {
                    var draft = card
                    draft.deck = Flashcard.myDeck
                    guard let saved = await store.add(draft) else { return }
                    if store.selectedDeck == nil || store.selectedDeck == saved.deck {
                        withAnimation(FLIGHT.spring) { queue.insert(saved, at: 0); flipped = false }
                    }
                }
            }
        }
        .sheet(isPresented: $generating) {
            GenerateCardsView()
        }
        .alert("Clear all your flashcards?", isPresented: $confirmingClear) {
            Button("Clear \(store.mineCount) cards", role: .destructive) {
                Task { await store.clearMine(); resetQueue() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every card you wrote or generated. It can't be undone.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.problem ?? "")
        }
        .overlay(alignment: .bottom) { noticeToast }
        .onChange(of: store.selectedDeck) { resetQueue() }
        .onChange(of: store.cards.count) { if queue.isEmpty { resetQueue() } }
        .task {
            await store.load()
            resetQueue()
            await dealIn()
            #if DEBUG
            switch DebugLaunch.screen {
            case "cards-flip": flipped = true
            case "cards-correct": flipped = true; verdict = .correct
            case "cards-unknown": flipped = true; verdict = .unknown
            case "cards-new", "cards-new-color", "cards-new-answer": composing = true
            case "cards-add": choosingAdd = true
            case "cards-generate": generating = true
            default: break
            }
            #endif
        }
    }

    // MARK: Decks and states

    private var deckChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("All", count: store.cards.count, on: store.selectedDeck == nil) { store.selectedDeck = nil }
                ForEach(store.decks, id: \.self) { deck in
                    chip(deck, count: store.cards.filter { $0.deck == deck }.count, on: store.selectedDeck == deck) {
                        store.selectedDeck = deck
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .trailingFade()
        .padding(.horizontal, -20)
    }

    private func chip(_ title: String, count: Int, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(title) · \(count)")
                .font(.system(size: 15, weight: on ? .semibold : .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                // Static glass: interactive glass flares white while held, too bright for a filter chip.
                .glassFill(on ? Theme.accent : Theme.faint, in: Capsule(), strength: on ? 1 : 0.7, interactive: false)
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Centered, with one primary action; writing your own is the quieter alternative.
    private var emptyState: some View {
        VStack(spacing: 12) {
            AppIcon(.cards, size: 44).foregroundStyle(Theme.accent)
                .frame(width: 84, height: 84)
                .background(Theme.accentSoft, in: Circle())
            Text("No cards yet").font(.system(size: 24, weight: .bold)).padding(.top, 6)
            Text("Generate a deck for the topics you're studying, or write your own.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("Generate cards") { generating = true }
                .buttonStyle(PrimaryButtonStyle(height: 52))
                .padding(.top, 14)
            Button("Write your own card") { composing = true }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var noticeToast: some View {
        if let notice = store.notice {
            Text(notice)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.good)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.goodSoft, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.3)) { store.notice = nil }
                }
        }
    }

    // MARK: Deck

    private var deck: some View {
        let shown = Array(queue.prefix(DECK.visible).enumerated())
        return ZStack {
            ForEach(shown.reversed(), id: \.element.id) { depth, card in
                CardFace(card: card,
                         flipped: depth == 0 && flipped,
                         glow: depth == 0 ? verdictColor : nil)
                    .scaleEffect(1 - CGFloat(depth) * DECK.depthScale, anchor: .bottom)
                    .offset(y: CGFloat(depth) * DECK.depthOffset)
                    // deal-in: launch from under the screen edge, fanned; cards stay opaque
                    .offset(y: dealt ? 0 : DECK.dealFrom)
                    .rotationEffect(.degrees(dealt ? 0 : DECK.fan * Double(depth - 1)))
                    .animation(reduceMotion ? nil : DECK.deal.delay(TIMING.dealStart + Double(DECK.visible - 1 - depth) * TIMING.dealStagger), value: dealt)
                    .animation(FLIGHT.spring, value: queue)
                    .zIndex(Double(DECK.visible - depth))
                    .onTapGesture { if depth == 0 { flip() } }
                    .transition(flyOff)
                    .accessibilityAddTraits(depth == 0 ? .isButton : [])
                    .accessibilityHidden(depth != 0)
            }
        }
        .frame(height: DECK.cardHeight + DECK.depthOffset * CGFloat(DECK.visible - 1))
    }

    /// Removal edge depends on the verdict that sent the card away.
    private var flyOff: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let dir: CGFloat = verdict == .correct ? 1 : -1
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .modifier(
                active: FlyModifier(x: dir * FLIGHT.distance, angle: Double(dir) * FLIGHT.tilt, opacity: 0),
                identity: FlyModifier(x: 0, angle: 0, opacity: 1)
            )
        )
    }

    private var verdictColor: Color? {
        switch verdict {
        case .correct: Theme.correct
        case .unknown: Theme.wrong
        case nil: nil
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            VerdictButton(title: "I don't know", glyph: .x, tint: Theme.wrong, lit: verdict == .unknown) {
                answer(.unknown)
            }
            VerdictButton(title: "Correct", glyph: .check, tint: Theme.correct, lit: verdict == .correct) {
                answer(.correct)
            }
        }
        .disabled(busy)
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)
            AppIcon(.cards, size: 44).foregroundStyle(Theme.accent)
            Text("Deck complete").font(.system(size: 24, weight: .bold))
            HStack(spacing: 28) {
                stat("\(known)", "Knew it", Theme.correct)
                stat("\(missed)", "Practised again", Theme.wrong)
            }
            Button("Study again", action: restart)
                .buttonStyle(PrimaryButtonStyle(height: 52))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.mono(28)).foregroundStyle(color)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }

    // MARK: Actions

    /// Deals the deck in on the first visit of this app session; later visits show it in place.
    private func dealIn(force: Bool = false) async {
        guard force || !flashcardsHaveDealt else { return }
        flashcardsHaveDealt = true
        if reduceMotion { dealt = true; hintShown = true; controlsShown = true; return }
        dealt = false
        try? await Task.sleep(for: .milliseconds(30))
        dealt = true
        Task { try? await Task.sleep(for: .seconds(TIMING.hint)); withAnimation(.easeOut(duration: 0.3)) { hintShown = true } }
        try? await Task.sleep(for: .seconds(TIMING.buttons))
        withAnimation(Springs.slide) { controlsShown = true }
    }

    private func flip() {
        withAnimation(FLIP.spring) { flipped.toggle() }
    }

    private func answer(_ v: Verdict) {
        guard !busy, let card = queue.first else { return }
        busy = true
        withAnimation(.easeOut(duration: 0.15)) { verdict = v }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(TIMING.verdictHold))
            withAnimation(FLIGHT.spring) {
                queue.removeFirst()
                if v == .correct { known += 1 } else {
                    missed += 1
                    queue.append(card.copy())  // comes back later
                }
                flipped = false
            }
            try? await Task.sleep(for: .seconds(TIMING.settle - TIMING.verdictHold))
            withAnimation(.easeOut(duration: 0.2)) { verdict = nil }
            busy = false
        }
    }

    /// Starts the selected deck from its first card.
    private func resetQueue() {
        queue = store.studying.map { $0.copy() }
        known = 0; missed = 0; flipped = false
    }

    private func openPendingAdd() {
        switch pendingAdd {
        case .write?: composing = true
        case .generate?: generating = true
        case nil: break
        }
        pendingAdd = nil
    }

    private func restart() {
        withAnimation(Springs.card) {
            queue = store.studying.map { $0.copy() }
            known = 0; missed = 0; flipped = false
            dealt = false; controlsShown = false; hintShown = false
        }
        Task { await dealIn(force: true) }
    }
}

// MARK: - Pieces

private struct FlyModifier: ViewModifier {
    let x: CGFloat
    let angle: Double
    let opacity: Double
    func body(content: Content) -> some View {
        content.offset(x: x).rotationEffect(.degrees(angle)).opacity(opacity)
    }
}

/// Two-sided card: question on the front, answer on the back, turned on the Y axis.
struct CardFace: View {
    let card: Flashcard
    let flipped: Bool
    let glow: Color?
    var height: CGFloat = DECK.cardHeight
    var textSize: CGFloat = 24

    var body: some View {
        ZStack {
            side(label: "\(card.topic) · Question", text: card.front)
                .opacity(flipped ? 0 : 1)
            side(label: "\(card.topic) · Answer", text: card.back)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(card.color.tint.opacity(card.color.wash))
                .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(glow ?? (card.color == .standard ? Theme.ring : card.color.tint.opacity(0.45)),
                              lineWidth: glow == nil ? 1 : 2.5)
        )
        .shadow(color: (glow ?? .black).opacity(glow == nil ? 0.08 : 0.35), radius: glow == nil ? 10 : 16, y: 4)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flipped ? "Answer: \(card.back)" : "Question: \(card.front)")
        .accessibilityHint(flipped ? "" : "Double-tap to flip")
    }

    private func side(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(label, color: card.color.tint)
            Spacer()
            Text(text)
                .font(.system(size: textSize, weight: .semibold))
                .lineSpacing(3)
                .minimumScaleFactor(0.8)
            Spacer()
            // Generated cards say where their facts came from, so a reader can check them.
            if let source = card.sourceLabel {
                HStack(spacing: 6) {
                    AppIcon(.bookOpen, size: 14)
                    Text("Source: \(source)").lineLimit(1)
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Neutral at rest; fills with its colour when chosen.
private struct VerdictButton: View {
    let title: String
    let glyph: IconGlyph
    let tint: Color
    let lit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIcon(glyph, size: 18)
                Text(title)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .glassFill(tint, in: Capsule())
            .shadow(color: tint.opacity(lit ? 0.55 : 0), radius: 14)
            .scaleEffect(lit ? 1.05 : 1)
            .animation(Springs.pop, value: lit)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - New card

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · New card sheet
 *
 *   swatch tap   ring springs onto the chosen colour; preview recolours (200ms)
 *   answer field focused     preview flips horizontally to its answer side
 *   question/topic focused   flips back to the question side
 *   (same 3D Y-axis turn as the deck: spring 0.5s, damping 0.8)
 *   save         sheet closes; new card springs onto the top of the deck
 * ───────────────────────────────────────────────────────── */

private enum SWATCH {
    static let size: CGFloat = 32
    static let ring: CGFloat = 3
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

private enum PREVIEW {
    static let flip = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

struct NewCardSheet: View {
    var onSave: (Flashcard) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var topic = ""
    @State private var front = ""
    @State private var back = ""
    @State private var color: CardColor = NewCardSheet.initialColor
    @State private var previewFlipped = false
    @FocusState private var focus: Field?
    private enum Field { case topic, question, answer }

    private static var initialColor: CardColor {
        #if DEBUG
        if DebugLaunch.screen == "cards-new-color" { return .purple }
        #endif
        return .standard
    }
    @Namespace private var ns

    private var canSave: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draft: Flashcard {
        Flashcard(topic: topic.isEmpty ? "My card" : topic,
                  front: front.isEmpty ? "Your question" : front,
                  back: back.isEmpty ? "Your answer" : back,
                  color: color)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardFace(card: draft, flipped: previewFlipped, glow: nil, height: 200, textSize: 20)
                        .onTapGesture { withAnimation(PREVIEW.flip) { previewFlipped.toggle() } }
                        .animation(.easeOut(duration: 0.2), value: color)

                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel("Color")
                        HStack(spacing: 0) {
                            ForEach(CardColor.allCases) { c in swatch(c).frame(maxWidth: .infinity) }
                        }
                    }

                    field("Topic", text: $topic, prompt: "e.g. Pharmacology", id: .topic)
                    field("Question", text: $front, prompt: "What should you recall?", lines: 3, id: .question)
                    field("Answer", text: $back, prompt: "The answer on the back", lines: 3, id: .answer)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .onChange(of: focus) { _, field in
                // Writing the answer turns the card over; question/topic turn it back.
                guard let field else { return }
                let showBack = field == .answer
                if showBack != previewFlipped { withAnimation(PREVIEW.flip) { previewFlipped = showBack } }
            }
            #if DEBUG
            .task {
                if DebugLaunch.screen == "cards-new-answer" {
                    try? await Task.sleep(for: .seconds(0.6))
                    focus = .answer
                }
            }
            #endif
            .navigationTitle("New card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(Flashcard(topic: topic.isEmpty ? "My card" : topic, front: front, back: back, color: color))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .tint(Theme.accent)
        .presentationDragIndicator(.visible)
    }

    private func swatch(_ c: CardColor) -> some View {
        let on = c == color
        return Button { withAnimation(SWATCH.spring) { color = c } } label: {
            ZStack {
                Circle()
                    .fill(c == .standard ? Theme.surface : c.tint)
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: c == .standard ? 1 : 0))
                    .frame(width: SWATCH.size, height: SWATCH.size)
                if on {
                    Circle()
                        .strokeBorder(Theme.text, lineWidth: SWATCH.ring)
                        .frame(width: SWATCH.size + 8, height: SWATCH.size + 8)
                        .matchedGeometryEffect(id: "ring", in: ns)
                }
            }
            .frame(width: SWATCH.size + 8, height: SWATCH.size + 8)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(c.name) card colour")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, lines: Int = 1, id: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.faint), axis: .vertical)
                .lineLimit(lines, reservesSpace: lines > 1)
                .focused($focus, equals: id)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border))
                .accessibilityLabel(label)
        }
    }
}
