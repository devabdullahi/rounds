import SwiftUI

struct PatientsView: View {
    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var system: OrganSystem? = nil   // nil = all topics
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var expanded: String?
    /// Beds picked for deletion; nil when not selecting. Holding a row starts it.
    @State private var selection: Set<String>?
    /// The row swiped open on Delete, so only one is open at a time.
    @State private var openRow: String?
    @State private var confirming: PendingDelete?
    /// A hold just started selecting on this row; its release mustn't also count as a tap.
    @State private var heldRow: String?

    /// Deletions that ask first. A single swipe doesn't: the swipe and the Delete tap are the ask.
    private enum PendingDelete: Equatable {
        case selected(Set<String>), all
    }

    init(initialExpanded: String? = nil) {
        _expanded = State(initialValue: initialExpanded)
    }

    private var rotation: [WardPatient] { filter(app.ward.filter { $0.status != .revisit }) }
    private var revisit: [WardPatient] { filter(app.revisitPatients) }

    var body: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Patients") { titleControls }

                progress

                searchField
                chips

                if !revisit.isEmpty {
                    sectionHeader("Worth a second visit", trailing: "\(revisit.count) patient\(revisit.count == 1 ? "" : "s")", color: Theme.warn)
                    VStack(spacing: 0) {
                        ForEach(Array(revisit.enumerated()), id: \.element.id) { i, p in
                            if i > 0 { Hairline() }
                            revisitRow(p)
                        }
                    }
                    .listSurface()
                }

                if !rotation.isEmpty {
                    sectionHeader(system?.label ?? "Your patients", trailing: "\(rotation.count)", color: Theme.muted)
                    VStack(spacing: 0) {
                        ForEach(Array(rotation.enumerated()), id: \.element.id) { i, p in
                            if i > 0 { Hairline() }
                            row(p)
                        }
                    }
                    .listSurface()
                }

                if app.ward.isEmpty {
                    emptyWard
                } else if rotation.isEmpty && revisit.isEmpty {
                    Text("No patients match \u{201C}\(query)\u{201D}.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .animation(Springs.slide, value: system)
            .animation(Springs.slide, value: query)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .refreshable { await app.refresh() }
        .safeAreaInset(edge: .bottom) {
            if let selection { selectionBar(selection).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(Springs.slide, value: selection != nil)
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: app.ward.map(\.id)) { _, ids in
            // Patients deleted elsewhere (or all of them) leave the selection too.
            if let s = selection { selection = s.intersection(ids) }
        }
        .alert(confirmTitle, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
               presenting: confirming) { pending in
            Button(confirmButton(pending), role: .destructive) { delete(pending) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Their cases, answers and grades are removed for good. Your rating stays.")
        }
        #if DEBUG
        .task(id: app.ward.count) { applyDebugMode() }
        #endif
    }

    // MARK: Deleting

    @ViewBuilder private var titleControls: some View {
        if selection != nil {
            Button("Done") { selection = nil }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minWidth: 44, minHeight: 44)
        } else if !app.ward.isEmpty {
            Menu {
                Button { selection = [] } label: {
                    Label { Text("Select patients") } icon: { Image(IconGlyph.check.assetName) }
                }
                Button(role: .destructive) { confirming = .all } label: {
                    Label { Text("Delete all patients") } icon: { Image(IconGlyph.trash.assetName) }
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
    }

    private func selectionBar(_ picked: Set<String>) -> some View {
        let visible = Set((revisit + rotation).map(\.id))
        let allPicked = !visible.isEmpty && visible.isSubset(of: picked)
        return HStack(spacing: 12) {
            Button(allPicked ? "Deselect all" : "Select all") {
                selection = allPicked ? picked.subtracting(visible) : picked.union(visible)
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
            Spacer(minLength: 8)
            Text(picked.isEmpty ? "Hold or tap to select" : "\(picked.count) selected")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Button {
                confirming = .selected(picked)
            } label: {
                Text("Delete")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .glassCapsule(tint: Theme.wrong)
            }
            .buttonStyle(PressDownStyle())
            .disabled(picked.isEmpty)
            .opacity(picked.isEmpty ? 0.4 : 1)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var confirmTitle: String {
        switch confirming {
        case .all: "Delete all patients?"
        case .selected(let beds): beds.count == 1 ? "Delete this patient?" : "Delete \(beds.count) patients?"
        case nil: ""
        }
    }

    private func confirmButton(_ pending: PendingDelete) -> String {
        switch pending {
        case .all: "Delete all \(app.ward.count)"
        case .selected(let beds): beds.count == 1 ? "Delete patient" : "Delete \(beds.count)"
        }
    }

    private func delete(_ pending: PendingDelete) {
        let beds: Set<String>? = if case .selected(let b) = pending { b } else { nil }
        selection = nil
        Task { await app.deletePatients(beds) }
    }

    private func deleteOne(_ bed: String) {
        Task { await app.deletePatients([bed]) }
    }

    /// Tap on a row: toggles it while selecting, otherwise does the row's own thing.
    private func tapped(_ bed: String, otherwise action: () -> Void) {
        if heldRow == bed { heldRow = nil; return }
        if var s = selection {
            if s.contains(bed) { s.remove(bed) } else { s.insert(bed) }
            selection = s
        } else {
            action()
        }
    }

    /// Holding a row starts selecting with that row picked.
    private func hold(_ bed: String) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            guard selection == nil else { return }
            heldRow = bed
            openRow = nil
            selection = [bed]
        }
    }

    @ViewBuilder private func selectMark(_ bed: String) -> some View {
        if let selection {
            let on = selection.contains(bed)
            ZStack {
                Circle().strokeBorder(Theme.faint, lineWidth: 1.5).opacity(on ? 0 : 1)
                if on {
                    Circle().fill(Theme.accent)
                    AppIcon(.check, size: 13).foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    #if DEBUG
    /// `-screen patients-select` / `patients-swipe`: show those states without gestures.
    private func applyDebugMode() {
        guard let first = (revisit + rotation).first else { return }
        switch app.debugPatientsMode {
        case "select": selection = Set((revisit + rotation).prefix(2).map(\.id))
        case "swipe": openRow = first.id
        default: break
        }
        app.debugPatientsMode = nil
    }
    #endif

    private var emptyWard: some View {
        VStack(spacing: 14) {
            Text("No patients yet. Each one is written fresh for your focus.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(app.isAdmitting ? "Preparing patient…" : "Admit a new patient") {
                Task { await app.admit(focus: FocusSelection(stored: focusStored)) }
            }
            .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
            .disabled(app.isAdmitting)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func filter(_ list: [WardPatient]) -> [WardPatient] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return list.filter { p in
            (system == nil || p.system == system) &&
            (q.isEmpty || [p.quote, p.meta, p.system?.label ?? "", p.id].contains { $0.lowercased().contains(q) })
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            AppIcon(.search, size: 18).foregroundStyle(Theme.muted)
            TextField("", text: $query, prompt: Text("Symptom, topic or bed").foregroundStyle(Theme.faint))
                .font(.system(size: 16))
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search patients")
            if !query.isEmpty {
                Button { query = "" } label: { AppIcon(.circleX, size: 18).foregroundStyle(Theme.faint).frame(width: 44, height: 44) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border.opacity(0.6)))
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach([nil] + app.wardSystems.map(Optional.some), id: \.self) { s in
                    let on = s == system
                    Button(s?.label ?? "All") { system = s }
                        .font(.system(size: 15, weight: on ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        // Static glass: interactive glass flares white while held, too bright for a filter chip.
                        .glassFill(on ? Theme.accent : Theme.faint, in: Capsule(), strength: on ? 1 : 0.7, interactive: false)
                        .buttonStyle(PressDownStyle())
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .trailingFade()
        .padding(.horizontal, -20)
    }

    private func sectionHeader(_ title: String, trailing: String, color: Color, trailingMono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(title, color: color)
            Spacer()
            Text(trailing)
                .font(trailingMono ? .mono(13, weight: .medium) : .system(size: 13))
                .foregroundStyle(trailingMono ? Theme.accent : Theme.muted)
        }
        .padding(.top, 2)
    }

    private func row(_ p: WardPatient) -> some View {
        Button {
            tapped(p.id) { Task { await app.open(bed: p.id) } }
        } label: {
            HStack(spacing: 12) {
                selectMark(p.id)
                Text(p.id).font(.mono(13)).foregroundStyle(Theme.muted).frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}\(p.quote)\u{201D}").font(.system(size: 16, weight: .semibold))
                    Text(p.meta).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if app.openingBed == p.id {
                    ProgressView()
                } else {
                    switch p.status {
                    case .new, .revisit:
                        EmptyView()   // new is the default; only exceptions get a badge
                    case .resume:
                        HStack(spacing: 6) { Circle().fill(Theme.info).frame(width: 8, height: 8); Text("Resume") }
                            .font(.system(size: 13)).foregroundStyle(Theme.info)
                    case .done:
                        Text(p.lastScore.map { "Scored \($0)" } ?? "Seen")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .simultaneousGesture(hold(p.id))
        .accessibilityAddTraits(selection?.contains(p.id) == true ? .isSelected : [])
        .swipeToDelete(id: p.id, openRow: $openRow, enabled: selection == nil) { deleteOne(p.id) }
    }

    // MARK: Revisit: what you missed on this patient

    private func revisitRow(_ p: WardPatient) -> some View {
        let isOpen = expanded == p.id
        let misses = p.misses
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                tapped(p.id) { withAnimation(DISCLOSURE.open) { expanded = isOpen ? nil : p.id } }
            } label: {
                HStack(spacing: 12) {
                    selectMark(p.id)
                    Text(p.id).font(.mono(13)).foregroundStyle(Theme.muted).frame(width: 28, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\u{201C}\(p.quote)\u{201D}").font(.system(size: 16, weight: .semibold))
                        HStack(spacing: 0) {
                            Text(misses.count == 1 ? "Missed: \(misses[0].flag.lowercased())" : "Missed \(misses.count) red flags")
                                .foregroundStyle(Theme.warn)
                            if let score = p.lastScore {
                                Text(", scored \(score)").foregroundStyle(Theme.muted)
                            }
                        }
                        .font(.system(size: 13))
                    }
                    Spacer(minLength: 8)
                    DisclosureChevron(open: isOpen)
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .simultaneousGesture(hold(p.id))
            .accessibilityAddTraits(selection?.contains(p.id) == true ? .isSelected : [])
            .accessibilityHint(selection != nil ? "Selects for deletion" : isOpen ? "Hide what you missed" : "Show what you missed")

            if isOpen && selection == nil {
                VStack(alignment: .leading, spacing: 12) {
                    FieldLabel("What you missed", color: Theme.warn)
                        .disclosureItem(0)
                    ForEach(Array(misses.enumerated()), id: \.element.id) { i, m in
                        MissItem(miss: m).disclosureItem(i + 1)
                    }
                    Button("Revisit \(p.id)") { Task { await app.open(bed: p.id) } }
                        .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
                        .padding(.top, 2)
                        .disclosureItem(misses.count + 1)
                }
                .padding(.horizontal, 16)
                .padding(.leading, 40)
                .padding(.bottom, 14)
            }
        }
        .clipped()
        .swipeToDelete(id: p.id, openRow: $openRow, enabled: selection == nil) { deleteOne(p.id) }
    }

    // MARK: Progress (moved from Home)

    private var progress: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Text("\(app.totalMisses)")
                    .font(.mono(30))
                    .foregroundStyle(Theme.warn)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Red flags you missed").font(.system(size: 17, weight: .semibold))
                    Text(missedSummary).font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
            }
            .card()
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Correct diagnosis").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Text("\(Int(app.rightDiagnosisRate * 100))%").font(.mono(26))
                    Text("up from 64%").font(.system(size: 13)).foregroundStyle(Theme.good)
                }
                .card(padding: 14, fillHeight: true)
                VStack(alignment: .leading, spacing: 0) {
                    // Progress through the student's own focus, not a fixed rotation.
                    Text(FocusSelection(stored: focusStored).isMix ? "All topics" : FocusSelection(stored: focusStored).label)
                        .font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                    Text("\(app.rotationDone)/\(app.rotationTotal)").font(.mono(26))
                    ProgressBar(value: Double(app.rotationDone) / Double(app.rotationTotal), height: 4)
                        .padding(.top, 6)
                }
                .card(padding: 14, fillHeight: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var missedSummary: String {
        let n = app.revisitPatients.count
        return n == 0 ? "None. Clean sweep." : "Across \(n) patient\(n == 1 ? "" : "s"), see below"
    }
}
