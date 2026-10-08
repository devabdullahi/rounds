import SwiftUI

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
