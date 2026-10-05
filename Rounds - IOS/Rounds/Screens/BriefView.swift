import SwiftUI

struct BriefView: View {
    @Environment(AppState.self) private var app
    @Environment(CaseRouter.self) private var router
    @Bindable var session: CaseSession
    /// Last chosen limit, remembered across cases. 0 = untimed.
    @AppStorage("timeLimitMinutes") private var savedLimit = 10

    private var clockRunning: Bool { session.startedAt != nil }

    private let limits: [(Int, String)] = [(5, "5 min"), (10, "10"), (15, "15"), (20, "20"), (0, "Off")]

    private var c: ClinicalCase { session.clinical }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Door note") {
                IconButton(glyph: .chevronLeft, label: "Back") { app.activeCase = nil }
            } trailing: { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Avatar(initials: c.initials, size: 64, fg: Theme.accent, bg: Theme.accentSoft)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.name), \(c.age)").font(.system(size: 22, weight: .bold))
                            Text(c.setting).font(.system(size: 15)).foregroundStyle(Theme.muted)
                        }
                    }

                    // The complaint is the story, not a widget: plain text, no card.
                    Text(c.complaint)
                        .font(.system(size: 17))
                        .lineSpacing(4)

                    // The task comes before setup: read what you're being timed on, then set the clock.
                    VStack(alignment: .leading, spacing: 4) {
                        FieldLabel("Your task")
                        Text(c.task).font(.system(size: 15)).foregroundStyle(Theme.dim).lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel("Triage vitals")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 12) {
                            ForEach(c.vitals) { v in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(v.label).font(.system(size: 13)).foregroundStyle(color(v.tone, label: true))
                                    Text(v.value)
                                        .font(.mono(22))
                                        .foregroundStyle(color(v.tone, label: false))
                                        .shadow(color: v.tone == .plain ? .clear : Theme.glow(color(v.tone, label: false), 0.4), radius: 6)
                                }
                            }
                        }
                    }
                    .card()

                    // Setup: both pre-room choices together, above the fold.
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel("Mode")
                            Segmented(options: [(false, "Practice"), (true, "Exam mode")], selection: $session.examMode)
                            Text(session.examMode ? "No hints. Findings stay hidden until the debrief." : "Findings are flagged as you uncover them.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .contentTransition(.opacity)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel("Time limit")
                            Segmented(options: limits, selection: Binding(
                                get: { savedLimit },
                                set: { savedLimit = $0; session.timeLimitMinutes = $0 == 0 ? nil : $0 }
                            ))
                            .accessibilityLabel("Time limit")
                            .disabled(clockRunning)
                            .opacity(clockRunning ? 0.5 : 1)
                            Text(clockRunning ? "Locked: the clock is already running."
                                 : savedLimit == 0 ? "No clock. Take as long as you need." : "The clock starts when you enter the room.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .contentTransition(.opacity)
                        }
                    }
                    .card()

                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)   // clears the bottom fade so the last line stays readable
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 32)
                    .allowsHitTesting(false)
            }

            Button("Enter the room") { router.go(.interview) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .background(Theme.bg)
        .onAppear {
            if session.startedAt == nil { session.timeLimitMinutes = savedLimit == 0 ? nil : savedLimit }
        }
    }

    private func color(_ tone: Vital.Tone, label: Bool) -> Color {
        switch tone {
        case .accent: Theme.accent
        case .warn: Theme.warn
        case .info: Theme.info
        case .plain: label ? Theme.muted : Theme.text
        }
    }
}
