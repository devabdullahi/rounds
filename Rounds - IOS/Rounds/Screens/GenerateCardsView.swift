import SwiftUI
import PhotosUI

/// Pick topics (or the student's own notes) and a card count, then generate a deck. While it's
/// written, cards deal in on loop.
struct GenerateCardsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""

    @State private var bySystem = false
    @State private var selection = FocusSelection()
    @State private var count = 20
    @State private var includeMisses = true
    @State private var fromNotes = false
    @State private var notes: StudyNotes?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pickingPDF = false

    private var store: FlashcardStore { app.flashcards }

    var body: some View {
        NavigationStack {
            Group {
                if store.isGenerating {
                    writing
                } else {
                    form
                }
            }
            .background(Theme.bg)
            .navigationTitle("Generate cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(store.isGenerating)
                }
            }
        }
        .tint(Theme.accent)
        .interactiveDismissDisabled(store.isGenerating)
        .presentationDragIndicator(.visible)
        .onAppear {
            // Start from the student's study focus.
            selection = FocusSelection(stored: focusStored)
            bySystem = selection.leadsWithSystem
            #if DEBUG
            if DebugLaunch.screen == "cards-generate-notes" {
                fromNotes = true
                notes = StudyNotes(title: "Heart failure lecture", amount: "3 pages", raw: String(repeating: "Sample notes line for screenshots.\n", count: 12))
            }
            #endif
        }
        .fileImporter(isPresented: $pickingPDF, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            Task { notes = await store.readNotes(pdf: url) }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var photos: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) { photos.append(data) }
                }
                photoItems = []
                notes = await store.readNotes(photos: photos)
            }
        }
        // The sheet covers Flashcards, whose own alert can't show until it closes.
        .alert("Something went wrong", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.problem ?? "")
        }
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Segmented(options: [(false, "Topics"), (true, "My notes")], selection: $fromNotes)

                if fromNotes {
                    notesPicker
                } else {
                    topicsPicker
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel("How many cards")
                    Segmented(options: FlashcardStore.generateCounts.map { ($0, "\($0)") }, selection: $count)
                }

                if !fromNotes {
                    Toggle(isOn: $includeMisses) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include what I missed").font(.system(size: 16, weight: .semibold))
                            Text("Red flags from your graded cases").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring))

                    Text("Cards are written from our condition profiles.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            // From notes the count is a ceiling: short notes support fewer good cards.
            Button(fromNotes ? "Generate up to \(count) cards" : "Generate \(count) cards", action: generate)
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .disabled(fromNotes && (notes == nil || store.isReadingNotes))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.bg)
        }
    }

    private var topicsPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel("Topics")
                Spacer()
                Text(selection.isMix ? "Mixed topics" : "\(selection.items.count) selected")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Segmented(options: [(false, "By rotation"), (true, "By system")], selection: $bySystem)
            // Compact chips, not the onboarding tiles, so count and options stay above the fold.
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.self) { topicChip($0) }
            }
            if selection.isMix {
                Text("None picked: you'll get a mix of everything.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Notes

    private var notesPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FieldLabel("Your notes")
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.track, in: Capsule())
            }
            // Once notes are picked the choice is made: removing them brings the buttons back.
            if notes == nil && !store.isReadingNotes {
                HStack(spacing: 10) {
                    Button { pickingPDF = true } label: { sourceTile(.filePDF, "PDF") }
                        .buttonStyle(PressDownStyle())
                    PhotosPicker(selection: $photoItems, maxSelectionCount: NotesReader.maxPhotos, matching: .images) {
                        sourceTile(.images, "Photos")
                    }
                    .buttonStyle(PressDownStyle())
                }
            }

            if store.isReadingNotes {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading your notes…").font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 6)
            } else if let notes {
                pickedNotes(notes)
            }

            VStack(alignment: .leading, spacing: 6) {
                noteLine(.info, "Still in early development: cards can have mistakes, so check them before you study.")
                noteLine(.shield, "Leave out patient names and anything that identifies a real person.")
            }
            .padding(.top, 2)
        }
    }

    private func noteLine(_ glyph: IconGlyph, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AppIcon(glyph, size: 16).foregroundStyle(Theme.muted).padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sourceTile(_ glyph: IconGlyph, _ title: String) -> some View {
        VStack(spacing: 8) {
            AppIcon(glyph, size: 26).foregroundStyle(Theme.accent)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring))
    }

    private func pickedNotes(_ notes: StudyNotes) -> some View {
        HStack(spacing: 12) {
            AppIcon(.fileText, size: 20).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(notes.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(notes.summary)
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            IconButton(glyph: .x, label: "Remove notes", quiet: true) { self.notes = nil }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring))
    }

    private var topics: [StudyFocus] {
        bySystem ? OrganSystem.allCases.map(StudyFocus.system) : Clerkship.allCases.map(StudyFocus.rotation)
    }

    private func topicChip(_ topic: StudyFocus) -> some View {
        let on = selection.contains(topic)
        return Button {
            withAnimation(Springs.pop) { selection.toggle(topic) }
        } label: {
            HStack(spacing: 6) {
                if on { AppIcon(.check, size: 14) }
                Text(topic.label)
            }
            .font(.system(size: 15, weight: on ? .semibold : .regular))
            .foregroundStyle(on ? Color.white : Theme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(on ? Theme.accent : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.border))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func generate() {
        Task {
            let done = if fromNotes, let notes {
                await store.generate(notes: notes, count: count)
            } else {
                await store.generate(focus: selection, count: count, includeMisses: includeMisses)
            }
            if done { dismiss() }
        }
    }

    // MARK: Writing

    private var writing: some View {
        VStack(spacing: 0) {
            Spacer()
            CardsDealing()
            Spacer().frame(height: 44)
            Eyebrow("Writing", color: Theme.accent)
            Text("Writing \(count) cards")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 10)
            Text("\(fromNotes ? notes?.deckName ?? "" : FlashcardStore.deckName(for: selection)). Usually under 30 seconds.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/* ANIMATION STORYBOARD · Cards dealing (writing a generated deck)
 *
 * Three blank cards, fanned, cycle in turn:
 *    0ms   card rises into place, y 40 → 0, fades in (450ms)
 *  450ms   its three lines fill left to right, staggered 150ms (900ms)
 * 1900ms   card lifts away, y 0 → −30, fades out (500ms)
 * Each card runs the same 2.4s loop, offset by a third.
 *
 * Reduce Motion: one card, lines filled, no loop.
 */
private enum DEALING {
    static let loop = 2.4
    static let rise = 0.19        // fraction of the loop
    static let fillStart = 0.19
    static let fillLength = 0.375
    static let lineStagger = 0.0625
    static let leave = 0.79
    static let tilts: [Double] = [-6, 4, 0]
}

private struct CardsDealing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = reduceMotion ? (i == 2 ? 0.5 : 0) : ((t / DEALING.loop) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    card(phase: phase)
                        .rotationEffect(.degrees(DEALING.tilts[i]))
                        .opacity(reduceMotion && i != 2 ? 0 : 1)
                }
            }
        }
        .frame(width: 300, height: 200)
        .accessibilityHidden(true)
    }

    private func card(phase: Double) -> some View {
        let enter = min(1, phase / DEALING.rise)
        let exit = max(0, (phase - DEALING.leave) / (1 - DEALING.leave))
        return VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Theme.accentSoft).frame(width: 110, height: 10)
            ForEach(0..<3, id: \.self) { line in
                let start = DEALING.fillStart + Double(line) * DEALING.lineStagger
                let fill = min(1, max(0, (phase - start) / DEALING.fillLength))
                Capsule().fill(Theme.track)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(Theme.faint).frame(width: g.size.width * fill) }
                    }
                    .frame(width: [250, 210, 150][line], height: 12)
            }
        }
        .padding(22)
        .frame(width: 300, height: 200, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.ring))
        .offset(y: 40 * (1 - enter) - 30 * exit)
        .opacity(enter * (1 - exit))
    }
}
