import SwiftUI

/// The case screen's bottom bar: Ask, Examine and Tests, each one tap away with its progress, and
/// Diagnose at the end. It replaced a History | Workup switch that hid the exam and tests a level
/// down, where students didn't find them. A dot marks the step worth trying next.
struct CaseStepBar: View {
    struct Step: Identifiable {
        let step: WorkupStep
        let label: String
        let glyph: IconGlyph
        /// "6/14", or nil while the total isn't known yet.
        let progress: String?
        let spokenProgress: String?
        var id: WorkupStep { step }
    }

    let steps: [Step]
    let current: WorkupStep
    let hint: WorkupStep?
    /// Enough workup done that diagnosing is the natural next move: Diagnose turns solid.
    let readyToDiagnose: Bool
    let select: (WorkupStep) -> Void
    let diagnose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(steps) { s in
                stepButton(s)
            }
            diagnoseButton
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1) }
    }

    private func stepButton(_ s: Step) -> some View {
        let on = s.step == current
        return Button { select(s.step) } label: {
            VStack(spacing: 3) {
                AppIcon(s.glyph, size: 20)
                    .overlay(alignment: .topTrailing) {
                        if s.step == hint && !on {
                            Circle().fill(Theme.accent).frame(width: 8, height: 8).offset(x: 6, y: -3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(s.label).font(.system(size: 13, weight: .semibold))
                Text(s.progress ?? " ")
                    .font(.mono(11, weight: .medium))
                    .foregroundStyle(on ? Color.white.opacity(0.85) : Theme.muted)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(on ? Color.white : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background {
                // The open step is a glass button; the others are plain until tapped.
                if on {
                    Color.clear.glassFill(Theme.accentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(Springs.pop, value: hint)
        .accessibilityLabel(s.label)
        .accessibilityValue(s.spokenProgress ?? "")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(s.step == hint && !on ? "Suggested next" : "")
    }

    private var diagnoseButton: some View {
        Button(action: diagnose) {
            VStack(spacing: 3) {
                AppIcon(.sealCheck, size: 20)
                Text("Diagnose").font(.system(size: 13, weight: .semibold))
                Text(" ").font(.mono(11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 62)
            // Glass either way: slate until enough workup is done, then the accent.
            .glassFill(readyToDiagnose ? Theme.accentFill : Theme.neutralFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(Springs.slide, value: readyToDiagnose)
        .accessibilityLabel("Diagnose")
        .accessibilityHint("Commit to a diagnosis")
    }
}
