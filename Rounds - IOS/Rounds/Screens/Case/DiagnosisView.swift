import SwiftUI

struct DiagnosisView: View {
    @Environment(CaseRouter.self) private var router
    @Bindable var session: CaseSession

    @Environment(\.reference) private var reference
    @State private var assist = ReferenceAssist()
    /// Suggestions for the differential's add field, kept apart from the working diagnosis's.
    @State private var ddxAssist = ReferenceAssist()
    @State private var newDifferential = ""
    @FocusState private var focus: Field?
    private enum Field { case dx, ddx, plan }

    private let rowHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Your assessment") {
                IconButton(glyph: .chevronLeft, label: "Back") { router.back() }
            } trailing: {
                CountdownLabel(session: session)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Working diagnosis")
                        TextField("", text: $session.diagnosis, prompt: Text("Your working diagnosis").foregroundStyle(Theme.faint))
                            .font(.system(size: 18, weight: .semibold))
                            .focused($focus, equals: .dx)
                            .submitLabel(.next)
                            .onSubmit { focus = .plan }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focus == .dx ? Theme.accent : Theme.border))
                            .accessibilityLabel("Working diagnosis")

                        if focus == .dx, !assist.suggestions.isEmpty {
                            suggestionList(assist) { match in
                                session.diagnosis = assist.pick(match)
                                focus = .plan
                            }
                            .transition(.opacity.combined(with: .offset(y: -4)))
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: assist.suggestions)
                    .task(id: session.diagnosis) { await assist.diagnosisChanged(session.diagnosis) }

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("What else could it be?")
                            .accessibilityHint("Other conditions you considered, most likely first. Drag to reorder. Long-press one to remove it.")
                        VStack(spacing: 0) {
                        List {
                            ForEach(Array(session.differential.enumerated()), id: \.element) { i, item in
                                HStack(spacing: 12) {
                                    Text("\(i + 1)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 16)
                                    Text(item).font(.system(size: 16))
                                    Spacer(minLength: 8)
                                    Button {
                                        withAnimation(Springs.slide) { session.differential.removeAll { $0 == item } }
                                    } label: {
                                        AppIcon(.x, size: 14)
                                            .foregroundStyle(Theme.faint)
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove \(item)")
                                }
                                .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation(Springs.slide) { session.differential.removeAll { $0 == item } }
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8))
                                .listRowBackground(Theme.surface)
                                .listRowSeparatorTint(Theme.hairline)
                            }
                            .onMove { session.differential.move(fromOffsets: $0, toOffset: $1) }
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, .constant(.active))
                        .environment(\.defaultMinListRowHeight, rowHeight)
                        .contentMargins(.vertical, 0, for: .scrollContent)
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .frame(height: CGFloat(session.differential.count) * rowHeight)
                        .animation(Springs.slide, value: session.differential)

                        if !session.differential.isEmpty { Hairline().padding(.leading, 16) }
                        addDifferentialRow
                        }
                        .listSurface()
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focus == .ddx ? Theme.accent : Theme.border))

                        if focus == .ddx, !ddxAssist.suggestions.isEmpty {
                            suggestionList(ddxAssist) { match in
                                newDifferential = ddxAssist.pick(match)
                                addDifferential()
                            }
                            .transition(.opacity.combined(with: .offset(y: -4)))
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: ddxAssist.suggestions)
                    .task(id: newDifferential) { await ddxAssist.diagnosisChanged(newDifferential) }

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Immediate plan")
                        TextField("", text: $session.plan, prompt: Text("What do you do in the next 10 minutes?").foregroundStyle(Theme.faint), axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(4, reservesSpace: true)
                            .focused($focus, equals: .plan)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focus == .plan ? Theme.accent : Theme.border))
                            .accessibilityLabel("Immediate plan")

                        if !assist.drugs.isEmpty {
                            recognizedDrugs.transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: assist.drugs)
                    .task(id: session.plan) { await assist.planChanged(session.plan) }

                    HStack(alignment: .top, spacing: 12) {
                        AppIcon(.triangleAlert, size: 18).foregroundStyle(Theme.warnText)
                        Text("You can't change your answer after submitting. Grading checks how you got here, not just the answer.")
                            .font(.system(size: 14))
                            .lineSpacing(2)
                            .foregroundStyle(Theme.warnText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.warnSoft, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button("Submit to attending") {
                focus = nil
                router.go(.handoff)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session.diagnosis.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Theme.bg)
        .onAppear {
            assist.reference = reference
            ddxAssist.reference = reference
        }
        #if DEBUG
        .task {
            switch DebugLaunch.screen {
            case "diagnosis-suggest":
                session.diagnosis = "pulm"
                focus = .dx
            case "diagnosis-ddx", "diagnosis-ddx-add":
                session.differential = ["Pulmonary embolism", "Pneumonia", "Acute coronary syndrome"]
                if DebugLaunch.screen == "diagnosis-ddx-add" {
                    newDifferential = "pne"
                    focus = .ddx
                }
            default: break
            }
        }
        #endif
        .onChange(of: focus) {
            if focus != .dx { assist.dismissSuggestions() }
            if focus != .ddx { ddxAssist.dismissSuggestions() }
        }
    }

    // MARK: Differential

    /// The last row of the differential: type a diagnosis, Return adds it and stays ready for the next.
    private var addDifferentialRow: some View {
        HStack(spacing: 12) {
            TextField("", text: $newDifferential, prompt: Text("Add another possibility").foregroundStyle(Theme.faint))
                .font(.system(size: 16))
                .focused($focus, equals: .ddx)
                .submitLabel(.done)
                .onSubmit(addDifferential)
                .accessibilityLabel("Add another possibility")
            if !newDifferential.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: addDifferential)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture { focus = .ddx }
    }

    /// Adds the typed diagnosis (once) and keeps the field focused for the next one.
    private func addDifferential() {
        let d = newDifferential.trimmingCharacters(in: .whitespaces)
        guard !d.isEmpty else { return }
        if !session.differential.contains(where: { $0.caseInsensitiveCompare(d) == .orderedSame }) {
            withAnimation(Springs.slide) { session.differential.append(d) }
        }
        newDifferential = ""
        ddxAssist.dismissSuggestions()
        focus = .ddx
    }

    // MARK: Reference helpers

    /// Standard condition names as the student types; tapping one uses it.
    private func suggestionList(_ assist: ReferenceAssist, onPick: @escaping (ConditionMatch) -> Void) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(assist.suggestions.enumerated()), id: \.element.id) { i, match in
                Button {
                    onPick(match)
                } label: {
                    HStack(spacing: 12) {
                        Text(match.name).font(.system(size: 16)).foregroundStyle(Theme.text)
                        Spacer(minLength: 8)
                        // Why it matched, when the name doesn't show it: teaches the abbreviation.
                        if let hint = assist.hint(for: match) {
                            Text(hint).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Uses this diagnosis")
                if i < assist.suggestions.count - 1 { Hairline() }
            }
        }
        .listSurface()
    }

    /// Drugs found in the plan, so the student sees what will be read as a medication.
    private var recognizedDrugs: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recognized drugs").font(.system(size: 13)).foregroundStyle(Theme.muted)
            FlowLayout(spacing: 6) {
                ForEach(assist.drugs) { drug in
                    Pill(text: drug.name, glyph: .check)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}
