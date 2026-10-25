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
    /// The patient whose previous tries are open in a sheet.
    @State private var tries: PastTries?
    /// The tab the student picked; nil until they pick, so it opens on what's most useful.
    @State private var chosenTab: Tab?
    @State private var searching = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Switching tabs: the glass fades onto the tapped tab and the list cross-fades, quick and even,
    /// instead of the pill popping and rows springing into place.
    private enum TABS {
        static let fade = Animation.easeOut(duration: 0.22)
    }

    private enum DELETE {
        /// Rows below a deleted one move up as it collapses (Mail-like).
        static let collapse = Animation.smooth(duration: 0.32)
    }

    /// Deletions that ask first. A single swipe doesn't: the swipe and the Delete tap are the ask.
    private enum PendingDelete: Equatable {
        case selected(Set<String>), all
    }

    init(initialExpanded: String? = nil) {
        _expanded = State(initialValue: initialExpanded)
    }

    /// The three tabs, in the order a student works through a patient.
    private enum Tab: Hashable, CaseIterable {
        case inProgress, new, seen
        var title: String {
            switch self {
            case .inProgress: "In progress"
            case .new: "New"
            case .seen: "Seen"
            }
        }
    }

    private var inProgress: [WardPatient] { filter(app.ward.filter { $0.status == .resume }) }
    private var newPatients: [WardPatient] { filter(app.ward.filter { $0.status == .new }) }
    private var revisit: [WardPatient] { filter(app.revisitPatients) }
    private var seen: [WardPatient] { filter(app.ward.filter { $0.status == .done }) }

    /// Opens on a case to finish when there is one, else on new patients.
    private var tab: Tab { chosenTab ?? (app.ward.contains { $0.status == .resume } ? .inProgress : .new) }

    private func count(_ t: Tab) -> Int {
        switch t {
        case .inProgress: inProgress.count
        case .new: newPatients.count
        case .seen: revisit.count + seen.count
        }
    }

    var body: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Patients") { titleControls }

                if !app.ward.isEmpty {
                    statsLine
                    if searching { searchField.transition(.opacity.combined(with: .move(edge: .top))) }
                    tabBar
                    VStack(alignment: .leading, spacing: 14) {
                        switch tab {
                        case .inProgress: inProgressList
                        case .new: newList
                        case .seen: seenList
                        }
                    }
                    .id(tab)
                    .transition(.opacity)
                }

                if app.ward.isEmpty {
                    emptyWard
                } else if !query.isEmpty && count(tab) == 0 {
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
            .animation(reduceMotion ? nil : TABS.fade, value: tab)
            .animation(Springs.slide, value: searching)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .refreshable { await app.refresh() }
        .safeAreaInset(edge: .bottom) {
            if let selection { selectionBar(selection).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(Springs.slide, value: selection != nil)
        .haptic(.selection, trigger: selection)
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
        .sheet(item: $tries) { PreviousTriesView(model: $0) }
        #if DEBUG
        .task(id: app.ward.count) { applyDebugMode() }
        .onAppear {
            if DebugLaunch.screen == "patients-new" { chosenTab = .new }
            if DebugLaunch.screen == "patients-seen" || DebugLaunch.screen == "patients-open" { chosenTab = .seen }
        }
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
            Button {
                searching.toggle()
                if !searching { query = "" }
            } label: {
                AppIcon(searching ? .x : .search, size: 20)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .glassCircle(tint: Theme.faint)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(searching ? "Close search" : "Search patients")
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
        let visible = Set((inProgress + newPatients + revisit + seen).map(\.id))
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

    private var rowExit: AnyTransition { reduceMotion ? .opacity : .collapse }

    private func delete(_ pending: PendingDelete) {
        let beds: Set<String>? = if case .selected(let b) = pending { b } else { nil }
        withAnimation(DELETE.collapse) {
            selection = nil
            app.deletePatients(beds)
        }
    }

    private func deleteOne(_ bed: String) {
        withAnimation(DELETE.collapse) { app.deletePatients([bed]) }
    }

    /// Tap on a row: toggles it while selecting, otherwise does the row's own thing. A swipe's
    /// lifting finger also reaches the row's button, so a row being swiped never opens; a tap on
    /// another row just closes the open one.
    private func tapped(_ bed: String, otherwise action: () -> Void) {
        if heldRow == bed { heldRow = nil; return }
        if let open = openRow {
            if open != bed { openRow = nil }
            return
        }
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
        if ["previous-tries", "previous-try"].contains(DebugLaunch.screen), tries == nil {
            tries = PastTries(bed: "debug", tries: PastTry.debugSamples)
        }
        guard let first = (inProgress + newPatients + revisit + seen).first else { return }
        switch app.debugPatientsMode {
        case "select": selection = Set((inProgress + newPatients + revisit + seen).prefix(2).map(\.id))
        case "swipe": openRow = first.id
        case "delete":
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(DELETE.collapse) { app.debugHide(bed: first.id) }
            }
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

    /// The bed code column: wide enough for five characters ("SD595"), shrinking rather than wrapping.
    private func bedLabel(_ bed: String) -> some View {
        Text(bed)
            .font(.mono(13))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 44, alignment: .leading)
    }

    private func row(_ p: WardPatient) -> some View {
        Button {
            tapped(p.id) { Task { await app.open(bed: p.id) } }
        } label: {
            HStack(spacing: 12) {
                selectMark(p.id)
                // Two lines at most, no bed code: the list is for scanning, the full quote waits in the door note.
                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}\(p.quote)\u{201D}").font(.system(size: 16, weight: .semibold)).lineLimit(2)
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
                    bedLabel(p.id)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\u{201C}\(p.quote)\u{201D}").font(.system(size: 16, weight: .semibold))
                        HStack(spacing: 0) {
                            Text(p.missedDiagnosis != nil ? "Missed the diagnosis"
                                 : misses.count == 1 ? "Missed: \(misses[0].flag.lowercased())" : "Missed \(misses.count) red flags")
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
                    // The diagnosis leads when it was missed; red flags follow as the rest of what to fix.
                    if let diagnosis = p.missedDiagnosis {
                        VStack(alignment: .leading, spacing: 2) {
                            FieldLabel("Diagnosis", color: Theme.warn)
                            Text(diagnosis).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                        }
                        .accessibilityElement(children: .combine)
                        .disclosureItem(0)
                    }
                    if !misses.isEmpty {
                        FieldLabel(p.missedDiagnosis != nil ? "Red flags you missed" : "What you missed", color: Theme.warn)
                            .padding(.top, p.missedDiagnosis != nil ? 4 : 0)
                            .disclosureItem(1)
                        ForEach(Array(misses.enumerated()), id: \.element.id) { i, m in
                            MissItem(miss: m).disclosureItem(i + 2)
                        }
                    }
                    HStack(spacing: 10) {
                        Button("Revisit \(p.id)") { Task { await app.open(bed: p.id) } }
                            .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
                        if p.tries > 0 {
                            Button(p.tries == 1 ? "Previous try" : "Previous tries (\(p.tries))") {
                                tries = PastTries(bed: p.id, service: app.cases)
                            }
                            .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16, tint: Theme.dim))
                        }
                    }
                    .padding(.top, 2)
                    .disclosureItem(misses.count + 2)
                }
                .padding(.horizontal, 16)
                .padding(.leading, 40)
                .padding(.bottom, 14)
            }
        }
        .clipped()
        .swipeToDelete(id: p.id, openRow: $openRow, enabled: selection == nil) { deleteOne(p.id) }
    }

    // MARK: Tabs

    /// One quiet line instead of the old stat cards: the list is what this screen is for.
    private var statsLine: some View {
        HStack(spacing: 16) {
            (Text("\(app.totalMisses)").font(.system(size: 15, weight: .bold)).foregroundColor(Theme.warn)
                + Text(" red flags missed"))
            (Text(app.rightDiagnosisText).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                + Text(" right diagnosis"))
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.muted)
        .accessibilityElement(children: .combine)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                let on = t == tab
                Button {
                    withAnimation(reduceMotion ? nil : TABS.fade) { chosenTab = t }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(t.title) \(count(t))")
                        // A patient worth a second visit is waiting behind Seen.
                        if t == .seen && !revisit.isEmpty && !on {
                            Circle().fill(Theme.warn).frame(width: 8, height: 8)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    // Always drawn, faded in and out, so selecting never pops the glass in.
                    .background {
                        Color.clear
                            .glassFill(Theme.accentFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: false)
                            .opacity(on ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressDownStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityHint(t == .seen && !revisit.isEmpty ? "Includes patients worth a second visit" : "")
            }
        }
        .padding(4)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sensoryFeedback(.selection, trigger: tab)
    }

    @ViewBuilder private var inProgressList: some View {
        if inProgress.isEmpty {
            tabEmpty("Nothing in progress. Start someone from New.")
        } else {
            VStack(spacing: 10) {
                ForEach(inProgress) { p in resumeCard(p).transition(rowExit) }
            }
            Text(inProgress.count == 1 ? "Finish this one, or start someone new from the New tab."
                                       : "Finish these, or start someone new from the New tab.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
    }

    /// The case to finish: outlined in the accent so it reads as "yours, underway", Resume on the right.
    private func resumeCard(_ p: WardPatient) -> some View {
        Button {
            tapped(p.id) { Task { await app.open(bed: p.id) } }
        } label: {
            HStack(spacing: 12) {
                selectMark(p.id)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.shortComplaint).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                    Text(p.meta).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    if let found = p.historyFound, p.historyTotal > 0 {
                        historyDashes(found: found, total: p.historyTotal)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 8)
                if app.openingBed == p.id {
                    ProgressView()
                } else {
                    Text("Resume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .glassCapsule(tint: Theme.accentFill)
                }
            }
            .foregroundStyle(Theme.text)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .simultaneousGesture(hold(p.id))
        .accessibilityAddTraits(selection?.contains(p.id) == true ? .isSelected : [])
        .accessibilityHint("Picks up where you left off")
        .swipeToDelete(id: p.id, openRow: $openRow, enabled: selection == nil) { deleteOne(p.id) }
        // The swipe row paints a square surface behind the card; keep it inside the card's corners.
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Key history found so far, one dash per area, the same count the case screen's bar shows.
    private func historyDashes(found: Int, total: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i < found ? Theme.accent : Theme.track).frame(height: 5)
            }
        }
        .frame(maxWidth: 190)
        .accessibilityElement()
        .accessibilityLabel("Key history \(found) of \(total)")
    }

    @ViewBuilder private var newList: some View {
        if !app.wardSystems.isEmpty { systemFilter }
        if newPatients.isEmpty {
            VStack(spacing: 14) {
                tabEmpty(system == nil ? "No new patients waiting." : "No new \(system?.label.lowercased() ?? "") patients.")
                admitButton
            }
        } else {
            list(newPatients)
            admitButton.frame(maxWidth: .infinity)
        }
    }

    /// One button for the body-system filter, in place of a row of chips that ran off the screen.
    private var systemFilter: some View {
        Menu {
            Button("All systems") { system = nil }
            ForEach(app.wardSystems, id: \.self) { s in
                Button(s.label) { system = s }
            }
        } label: {
            HStack(spacing: 6) {
                Text(system?.label ?? "All systems")
                AppIcon(.chevronDown, size: 14)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .glassCapsule(tint: Theme.neutralFill)
        }
        .accessibilityLabel("Body system: \(system?.label ?? "All systems")")
    }

    private var admitButton: some View {
        Button(app.isAdmitting ? "Preparing patient…" : "Admit a new patient") {
            Task { await app.admit(focus: FocusSelection(stored: focusStored)) }
        }
        .buttonStyle(QuietButtonStyle())
        .disabled(app.isAdmitting)
    }

    @ViewBuilder private var seenList: some View {
        if revisit.isEmpty && seen.isEmpty {
            tabEmpty("Patients you finish show up here with their scores.")
        }
        if !revisit.isEmpty {
            sectionHeader("Worth a second visit", trailing: "\(revisit.count) patient\(revisit.count == 1 ? "" : "s")", color: Theme.warn)
            VStack(spacing: 0) {
                ForEach(Array(revisit.enumerated()), id: \.element.id) { i, p in
                    VStack(spacing: 0) {
                        if i > 0 { Hairline() }
                        revisitRow(p)
                    }
                    .transition(rowExit)
                }
            }
            .listSurface()
        }
        if !seen.isEmpty {
            sectionHeader("All seen", trailing: "\(seen.count)", color: Theme.muted)
            list(seen)
        }
    }

    private func list(_ patients: [WardPatient]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(patients.enumerated()), id: \.element.id) { i, p in
                VStack(spacing: 0) {
                    if i > 0 { Hairline() }
                    row(p)
                }
                .transition(rowExit)
            }
        }
        .listSurface()
    }

    private func tabEmpty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
    }
}
