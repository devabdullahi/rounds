import SwiftUI

struct PatientsView: View {
    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var system: OrganSystem? = nil   // nil = all topics
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var expanded: String?

    init(initialExpanded: String? = nil) {
        _expanded = State(initialValue: initialExpanded)
    }

    private var rotation: [WardPatient] { filter(app.ward.filter { $0.status != .revisit }) }
    private var revisit: [WardPatient] { filter(app.revisitPatients) }

    var body: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Patients")

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
    }

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
            Task { await app.open(bed: p.id) }
        } label: {
            HStack(spacing: 12) {
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
    }

    // MARK: Revisit: what you missed on this patient

    private func revisitRow(_ p: WardPatient) -> some View {
        let isOpen = expanded == p.id
        let misses = p.misses
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(DISCLOSURE.open) { expanded = isOpen ? nil : p.id }
            } label: {
                HStack(spacing: 12) {
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
            .accessibilityHint(isOpen ? "Hide what you missed" : "Show what you missed")

            if isOpen {
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
