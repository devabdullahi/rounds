import SwiftUI

/// One previous try at a patient: the grade, what the student answered, what they ordered and
/// examined, and the attending's feedback from that time.
struct PastTryView: View {
    let attempt: PastTry
    let number: Int
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Try \(number)") {
                IconButton(glyph: .chevronLeft, label: "Back", quiet: true, action: onBack)
            } trailing: { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    gradeCard
                    answerCard
                    workupCard
                    if !attempt.feedback.isEmpty { feedbackCard }
                    if !attempt.missedRedFlags.isEmpty { missesCard }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var gradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(attempt.submittedAt.formatted(date: .abbreviated, time: .shortened)) · \(attempt.examMode ? "Exam mode" : "Practice")")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnosis").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                Text(attempt.actualDiagnosis)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 6) {
                    AppIcon(attempt.diagnosisCorrect ? .check : .x, size: 14)
                        .foregroundStyle(attempt.diagnosisCorrect ? Theme.good : Theme.warnText)
                    Text(attempt.yourDiagnosis.isEmpty ? "No diagnosis submitted" : "You said \(attempt.yourDiagnosis)")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(attempt.diagnosisCorrect ? "Correct. You said \(attempt.yourDiagnosis)"
                                    : "Not correct. You said \(attempt.yourDiagnosis.isEmpty ? "nothing" : attempt.yourDiagnosis)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(attempt.score)").font(.score(40)).tracking(-1)
                    Text("/100").font(.score(17)).foregroundStyle(Theme.muted)
                }
                Pill(text: attempt.verdict,
                     fg: attempt.score >= 85 ? Theme.good : attempt.score >= 60 ? Theme.dim : Theme.warnText,
                     bg: attempt.score >= 85 ? Theme.goodSoft : attempt.score >= 60 ? Theme.track : Theme.warnSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, padding: 18)
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("Differential") {
                if attempt.differential.isEmpty { none } else {
                    FlowLayout(spacing: 8) {
                        ForEach(attempt.differential, id: \.self) { Pill(text: $0, fg: Theme.dim, bg: Theme.track) }
                    }
                }
            }
            section("Plan") {
                if attempt.plan.isEmpty { none } else {
                    Text(attempt.plan).font(.system(size: 15)).foregroundStyle(Theme.text).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var workupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("Tests ordered") {
                if attempt.testsOrdered.isEmpty { none } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(attempt.testsOrdered.enumerated()), id: \.offset) { i, name in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)").font(.mono(13)).foregroundStyle(Theme.faint).frame(width: 18, alignment: .leading)
                                Text(name).font(.system(size: 15)).foregroundStyle(Theme.text)
                            }
                        }
                    }
                }
            }
            section("Exam") {
                if attempt.examDone.isEmpty { none } else {
                    Text(attempt.examDone.joined(separator: ", ")).font(.system(size: 15)).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your attending").font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
            ForEach(Array(attempt.feedback.enumerated()), id: \.element.id) { i, f in
                if i > 0 { Hairline() }
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(f.tone == .good ? Theme.good : Theme.warn).frame(width: 8, height: 8).padding(.top, 7)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.title).font(.system(size: 16, weight: .semibold))
                        Text(f.detail).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
            Color.clear.frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listSurface()
    }

    private var missesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("Red flags you missed", color: Theme.warn)
            ForEach(attempt.missedRedFlags) { MissItem(miss: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(title)
            content()
        }
    }

    private var none: some View {
        Text("None").font(.system(size: 15)).foregroundStyle(Theme.faint)
    }
}
