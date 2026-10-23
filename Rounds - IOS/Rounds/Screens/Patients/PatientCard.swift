import SwiftUI

/// The incoming-patient card, for any patient on the ward.
struct PatientCard: View {
    let patient: WardPatient
    var stage: Int = 6
    var revisit = false
    /// The case is being fetched after a take.
    var opening = false
    /// While the card is being swiped, its button ignores touches entirely.
    var dragging = false
    var onTake: () -> Void

    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    private enum VITALS {
        static let stagger = 0.08
        static let offsetY: CGFloat = 8
        static let spring = Springs.pop
        static let hrJitter = [0, 0, 1, 0, -1, 0, 1]   // monitor flicker, one step per second
        static let beatGlow: CGFloat = 3
        static let beatScale: CGFloat = 0.04
        static let beatDecay = 0.14
    }

    /// The tag the focus didn't already cover: the system when the rotation matched, else the rotation.
    private var otherTag: String? {
        if let r = patient.rotation, focus.contains(.rotation(r)) { return patient.system?.label }
        return patient.rotation?.label
    }

    private var heartRate: Int {
        #if DEBUG
        if let override = DebugLaunch.heartRate { return override }
        #endif
        return patient.hr ?? 80
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Who: avatar + bed/meta, status on the right
            HStack(spacing: 14) {
                Text(patient.id)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    // Bed codes run up to five characters ("SD595"): shrink to fit the circle, never wrap.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 5)
                    .frame(width: 52, height: 52)
                    .background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(revisit ? "Revisit" : "Incoming").font(.system(size: 17, weight: .semibold))
                    Text(patient.meta).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    GlowDot(color: revisit ? Theme.info : Theme.warn, pulsing: !revisit)
                    Text(revisit ? "Retry" : "Waiting").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(revisit ? Theme.info : Theme.warn)
            }

            // Where it fits. A patient in the student's focus says so once, instead of
            // repeating the focus name that already sits above the deck.
            HStack(spacing: 6) {
                if !focus.isMix, patient.fits(focus) {
                    Pill(text: "Your focus", glyph: .target)
                    // Name whichever tag the focus didn't already cover.
                    if let other = otherTag {
                        Pill(text: other, fg: Theme.muted, bg: Theme.text.opacity(0.07))
                    }
                } else {
                    ForEach([patient.rotation?.label, patient.system?.label].compactMap { $0 }, id: \.self) { tag in
                        Pill(text: tag, fg: Theme.muted, bg: Theme.text.opacity(0.07))
                    }
                }
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 16)

            // What they say: the hero of the card
            Text("\u{201C}\(patient.quote)\u{201D}")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .lineSpacing(4)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(stage >= 3 ? 1 : 0)
                .offset(y: stage >= 3 ? 0 : VITALS.offsetY)
                .animation(Springs.slide, value: stage)

            Spacer(minLength: 20)

            // Monitor
            VStack(alignment: .leading, spacing: 12) {
                vitals
                ECGMonitor(bpm: Double(heartRate), stElevation: false)
                    .opacity(stage >= 2 ? 1 : 0)
            }

            Spacer(minLength: 24)

            Button(opening ? "Opening…" : revisit ? "Retry the patient" : "Take the patient", action: onTake)
                .buttonStyle(PrimaryButtonStyle(height: 54, reactive: false))   // non-interactive glass: never swells, even mid-swipe
                .allowsHitTesting(!dragging)
                .opacity(stage >= 4 ? 1 : 0)
                .scaleEffect(stage >= 4 ? 1 : 0.96)
                .animation(Springs.pop, value: stage)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: STACK.cardHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 24, y: 10)
    }

    private var vitals: some View {
        let items: [(String, Color, CGFloat)] = [("HR", Theme.accent, 34), ("BP", Theme.warn, 22), ("SpO₂", Theme.info, 34)]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.0).font(.system(size: 12)).foregroundStyle(item.1)
                    Group {
                        switch item.0 {
                        case "HR":
                            TimelineView(.animation) { ctx in
                                let tick = Int(ctx.date.timeIntervalSinceReferenceDate) % VITALS.hrJitter.count
                                let pulse = CGFloat(exp(-ECG.timeSinceBeat(at: ctx.date, bpm: Double(heartRate)) / VITALS.beatDecay))
                                Text("\(heartRate + VITALS.hrJitter[tick])")
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: tick)
                                    .scaleEffect(1 + VITALS.beatScale * pulse, anchor: .leading)
                                    .shadow(color: Theme.glow(Theme.accent, 0.45 + 0.35 * Double(pulse)),
                                            radius: 7 + VITALS.beatGlow * pulse)
                            }
                        case "BP": Text(patient.bp ?? "–").padding(.top, 8)
                        default: Text(patient.spo2.map(String.init) ?? "–")
                        }
                    }
                    .font(.mono(item.2))
                    .foregroundStyle(item.1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(stage >= 2 ? 1 : 0)
                .offset(y: stage >= 2 ? 0 : VITALS.offsetY)
                .animation(VITALS.spring.delay(Double(i) * VITALS.stagger), value: stage)
            }
        }
    }
}
