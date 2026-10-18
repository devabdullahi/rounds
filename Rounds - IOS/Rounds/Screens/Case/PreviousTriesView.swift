import SwiftUI

/// "Previous tries": every graded attempt at one patient, newest first. Tapping one opens what the
/// student answered and did that time, so a revisit can be compared with last time.
struct PreviousTriesView: View {
    let model: PastTries
    @Environment(\.dismiss) private var dismiss
    @State private var path: [PastTry] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                NavHeader(title: "Previous tries") {
                    IconButton(glyph: .x, label: "Close", quiet: true) { dismiss() }
                } trailing: { EmptyView() }
                content
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PastTry.self) { t in
                PastTryView(attempt: t, number: number(of: t)) { path.removeLast() }
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task {
            await model.load()
            #if DEBUG
            if DebugLaunch.screen == "previous-try", case .loaded(let tries) = model.phase, let first = tries.first { path = [first] }
            #endif
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).font(.system(size: 15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("Try again") { Task { await model.retry() } }
                    .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let tries) where tries.isEmpty:
            Text("No graded tries yet.").font(.system(size: 15)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let tries):
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(tries.enumerated()), id: \.element.id) { i, t in
                        if i > 0 { Hairline() }
                        row(t, number: tries.count - i)
                    }
                }
                .listSurface()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ t: PastTry, number: Int) -> some View {
        Button { path.append(t) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try \(number) · \(t.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    HStack(spacing: 6) {
                        AppIcon(t.diagnosisCorrect ? .check : .x, size: 14)
                            .foregroundStyle(t.diagnosisCorrect ? Theme.good : Theme.warnText)
                        Text(t.yourDiagnosis.isEmpty ? "No diagnosis" : t.yourDiagnosis)
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    }
                    Text(t.verdict).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("\(t.score)").font(.score(22)).foregroundStyle(Theme.text)
                AppIcon(.chevronRight, size: 14).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Try \(number), score \(t.score). You said \(t.yourDiagnosis.isEmpty ? "nothing" : t.yourDiagnosis), \(t.diagnosisCorrect ? "correct" : "not correct").")
    }

    /// Oldest is Try 1.
    private func number(of t: PastTry) -> Int {
        guard case .loaded(let tries) = model.phase, let i = tries.firstIndex(of: t) else { return 1 }
        return tries.count - i
    }
}
