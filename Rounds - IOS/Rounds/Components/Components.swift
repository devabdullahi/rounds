import SwiftUI

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    var radius: CGFloat = 16
    var padding: CGFloat = 16
    var fillHeight = false
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = 16, padding: CGFloat = 16, fillHeight: Bool = false) -> some View {
        modifier(CardModifier(radius: radius, padding: padding, fillHeight: fillHeight))
    }

    /// Grouped list container: rows separated by hairlines.
    func listSurface() -> some View {
        self
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

// MARK: - Buttons

/// Main action: accent-tinted Liquid Glass pill, white text.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 54
    var tint: Color = Theme.accent
    /// Off for buttons inside draggable cards: the glass must not swell when a swipe starts on it.
    var reactive = true
    func makeBody(configuration: Configuration) -> some View {
        if reactive {
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(.white)
                .glassFill(isEnabled ? tint : Theme.faint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous),
                           strength: isEnabled ? GLASS.tint : GLASS.disabled)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Springs.pop, value: configuration.isPressed)
        } else {
            // Static glass look (no live glass layer): nothing can swell, stretch or ripple it.
            let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(.white)
                .background(isEnabled ? tint : Theme.faint, in: shape)
                .overlay(
                    shape.fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                                              startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                )
                .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1).allowsHitTesting(false))
        }
    }
}

/// Secondary action: same glass and white text, slightly smaller type by default.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var fontSize: CGFloat = 17
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(.white)
            .glassFill(tint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous), strength: 0.75)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Springs.pop, value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct IconButton: View {
    let glyph: IconGlyph
    let label: String
    var size: CGFloat = 22
    /// Neutral glass for secondary navigation on screens whose primary action is already blue.
    var quiet = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            AppIcon(glyph, size: size * 0.8)
                .foregroundStyle(quiet ? Theme.text : .white)
                .frame(width: 38, height: 38)
                .glassCircle(tint: quiet ? Theme.text.opacity(0.10) : Theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Headers

struct NavHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    var body: some View {
        ZStack {
            // Title centers on the screen, not between the side controls: an empty side
            // (EmptyView) has no width and used to push the title off-center.
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 76)
            HStack {
                leading.frame(width: 64, alignment: .leading)
                Spacer()
                trailing.frame(width: 64, alignment: .trailing)
            }
            // A 22pt Phosphor caret in a 44pt hit box starts ~17pt in; 3pt lead puts its edge on the 20pt margin.
            .padding(.leading, 3)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

/// Timer stays quiet until it matters.
private enum TIMER {
    static let warnBelow: TimeInterval = 120   // turns coral
    static let pulseBelow: TimeInterval = 30   // starts pulsing
}

struct CountdownLabel: View {
    let session: CaseSession
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            if session.isTimed {
                let remaining = session.remaining(at: ctx.date)
                let urgent = remaining <= TIMER.warnBelow
                let critical = remaining <= TIMER.pulseBelow
                let pulseOn = critical && Int(remaining) % 2 == 0
                Text(CaseSession.format(remaining))
                    .font(.mono(17))
                    .foregroundStyle(urgent ? Theme.warn : Theme.dim)
                    .opacity(pulseOn ? 0.55 : 1)
                    .animation(.easeInOut(duration: 0.5), value: pulseOn)
                    .padding(.trailing, 8)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("\(Int(remaining) / 60) minutes \(Int(remaining) % 60) seconds left")
            } else {
                // Untimed: count up quietly, never turns urgent.
                let elapsed = session.elapsed(at: ctx.date)
                Text(CaseSession.format(elapsed))
                    .font(.mono(17))
                    .foregroundStyle(Theme.faint)
                    .padding(.trailing, 8)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(Int(elapsed) / 60) minutes \(Int(elapsed) % 60) seconds elapsed, untimed")
            }
        }
    }
}

// MARK: - Indicators

struct ProgressBar: View {
    var value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8
    @State private var shown: Double = 0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: geo.size.width * min(max(shown, 0), 1))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(Springs.card.delay(0.15)) { shown = value } }
        .onChange(of: value) { _, new in withAnimation(Springs.card) { shown = new } }
    }
}

struct GlowDot: View {
    var color: Color
    var pulsing = true
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color, radius: on ? 6 : 2)
            .opacity(on ? 1 : 0.55)
            .onAppear {
                guard pulsing else { on = true; return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

struct Pill: View {
    let text: String
    var fg: Color = Theme.accentText
    var bg: Color = Theme.accentSoft
    var glyph: IconGlyph? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let glyph { AppIcon(glyph, size: 13) }
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bg, in: Capsule())
    }
}

/// Initials in a circle, or the photo at `imageURL` once it loads (initials while loading or if it fails).
struct Avatar: View {
    let initials: String
    var size: CGFloat = 40
    var fg: Color = Theme.bg
    var bg: Color = Theme.text
    var imageURL: URL? = nil
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: Circle())
            .overlay {
                if let imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Segmented control

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Segmented control
 *
 * One persistent thumb, never re-inserted, so it always slides.
 *
 *   press   thumb shrinks 1.0 → 0.95 under the finger
 *   drag    thumb follows the finger segment to segment (scrub),
 *           selection haptic on every segment crossed
 *   tap     thumb springs to the tapped segment (interruptible:
 *           a second tap mid-flight redirects from where it is)
 *   release thumb springs back to 1.0; value commits
 *   labels  crossfade weight + color in place; widths never change
 * ───────────────────────────────────────────────────────── */

private enum SEG {
    static let height: CGFloat = 44
    static let inset: CGFloat = 3
    static let radius: CGFloat = 12
    static let thumbRadius: CGFloat = 9
    static let pressedScale: CGFloat = 0.95
    static let slide = Animation.spring(response: 0.32, dampingFraction: 0.82)   // thumb travel
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)    // squeeze in/out
    static let label = Animation.easeOut(duration: 0.18)                         // text crossfade
    static let thumb = Theme.thumb                                               // lifts off track and card
}

struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    @Environment(\.isEnabled) private var isEnabled
    @State private var pressing = false
    @State private var scrubIndex: Int?

    private var committedIndex: Int { options.firstIndex { $0.0 == selection } ?? 0 }
    private var shownIndex: Int { scrubIndex ?? committedIndex }

    var body: some View {
        GeometryReader { geo in
            let segW = (geo.size.width - 2 * SEG.inset) / CGFloat(max(options.count, 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: SEG.thumbRadius, style: .continuous)
                    .fill(SEG.thumb)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .frame(width: segW, height: geo.size.height - 2 * SEG.inset)
                    .scaleEffect(pressing ? SEG.pressedScale : 1)
                    .offset(x: SEG.inset + CGFloat(shownIndex) * segW)
                    .animation(SEG.slide, value: shownIndex)
                    .animation(SEG.press, value: pressing)

                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        let on = i == shownIndex
                        // Both weights are always laid out; only opacity changes, so nothing shifts.
                        ZStack {
                            Text(option.1).font(.system(size: 15, weight: .regular)).foregroundStyle(Theme.dim).opacity(on ? 0 : 1)
                            Text(option.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).opacity(on ? 1 : 0)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: segW, height: geo.size.height)
                        .animation(SEG.label, value: on)
                    }
                }
                .offset(x: SEG.inset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !pressing { pressing = true }
                        let i = min(max(Int((v.location.x - SEG.inset) / segW), 0), options.count - 1)
                        if scrubIndex != i { scrubIndex = i }
                    }
                    .onEnded { _ in
                        pressing = false
                        if let i = scrubIndex, options[i].0 != selection { selection = options[i].0 }
                        scrubIndex = nil
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: SEG.height)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: SEG.radius, style: .continuous))
        .sensoryFeedback(.selection, trigger: shownIndex)
        .accessibilityRepresentation {
            Picker("", selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - ECG trace

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · ECG monitor
 *
 * Works like a bedside monitor: the sweep moves across at a steady
 * speed and the heart rate sets how close together the beats sit.
 *
 *   104 bpm   4 beats per sweep, one R wave every 577ms
 *   130 bpm   5 beats per sweep, one R wave every 462ms
 *
 *   live   bright head sweeps left → right, fading tail behind it
 *   wrap   head re-enters on the left while the old tail fades on the right
 *   beat   the head crosses an R wave exactly once per heartbeat
 *
 * At high rates the gap between beats shrinks first (as on a real
 * ECG); the complex itself only narrows once there's no gap left.
 *
 * Dark mode: glowing trace, like a bedside monitor.
 * Light mode: black ink on pink chart paper (1 mm / 5 mm grid), no glow.
 * ───────────────────────────────────────────────────────── */

enum ECG {
    static let nominalWindow = 2.4       // s per sweep before snapping to whole beats
    static let tail: CGFloat = 0.55      // fraction of the width the fading trail covers
    static let complexWidth: CGFloat = 63   // P through T, in 354-unit trace space
    static let beatLead: CGFloat = 0.3   // where in each beat cell the P wave starts
    static let rOffset: CGFloat = 28     // P (10) + PR (10) + Q (3) + upstroke (5)
    static let lineWidth: CGFloat = 1.8

    /// Whole beats per sweep, so the trace repeats seamlessly when the head wraps.
    static func beatsPerSweep(_ bpm: Double) -> Int { max(2, Int((bpm * nominalWindow / 60).rounded())) }
    static func window(_ bpm: Double) -> Double { Double(beatsPerSweep(bpm)) * 60 / bpm }

    /// Seconds since the sweep head last crossed an R wave: drives heartbeat-synced effects.
    static func timeSinceBeat(at date: Date, bpm: Double) -> Double {
        let cell = 60 / bpm
        let n = CGFloat(beatsPerSweep(bpm))
        let cellUnits = 354 / n
        let k = complexScale(cellUnits)
        let rFraction = Double((ECG.beatLead * cellUnits + rOffset * k) / cellUnits)
        let phase = date.timeIntervalSinceReferenceDate / cell - rFraction
        return (phase - phase.rounded(.down)) * cell
    }

    /// Shrinks the complex so P→T ends inside its own cell, after the lead-in, with a short
    /// baseline before the next beat. Without this the last T wave overruns the right edge.
    static func complexScale(_ cellUnits: CGFloat) -> CGFloat {
        min(1, (cellUnits * (1 - beatLead) - 8) / complexWidth)
    }
}

/// Lead II trace: `beats` evenly spaced PQRST complexes across a 354×40 grid.
/// `stElevation` lifts the ST segment into a tombstone T wave, as in inferior leads of an STEMI.
/// Zero beats draws a flatline (asystole).
struct ECGShape: Shape {
    var beats: Int = 3
    var stElevation = false

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 354, sy = rect.height / 40
        guard beats > 0 else {
            var flat = Path()
            flat.move(to: CGPoint(x: 0, y: 26 * sy))
            flat.addLine(to: CGPoint(x: rect.width, y: 26 * sy))
            return flat
        }
        let cell = 354 / CGFloat(beats)
        let k = ECG.complexScale(cell)
        var p = Path()
        var x: CGFloat = 0
        func to(_ dx: CGFloat, _ y: CGFloat) { x += dx * k; p.addLine(to: CGPoint(x: x * sx, y: y * sy)) }
        p.move(to: CGPoint(x: 0, y: 26 * sy))
        for b in 0..<beats {
            x = CGFloat(b) * cell + ECG.beatLead * cell
            p.addLine(to: CGPoint(x: x * sx, y: 26 * sy))
            to(5, 21); to(5, 26); to(10, 26); to(3, 30)       // P, PR, Q
            to(5, 2); to(5, 36)                               // R, S
            if stElevation {
                to(4, 17); to(11, 15); to(7, 11); to(8, 26)   // J point → raised ST → T
            } else {
                to(4, 26); to(12, 26); to(7, 19); to(7, 26)
            }
        }
        p.addLine(to: CGPoint(x: 354 * sx, y: 26 * sy))
        return p
    }
}

/// Chart-paper grid: minor every 4pt (1 mm), heavier every 5th line (5 mm).
struct ECGPaperGrid: View {
    var minor: CGFloat = 4
    var body: some View {
        Canvas { ctx, size in
            var minorPath = Path(), majorPath = Path()
            var i = 0
            var x: CGFloat = 0
            while x <= size.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                i % 5 == 0 ? majorPath.addPath(p) : minorPath.addPath(p)
                x += minor; i += 1
            }
            i = 0
            var y = size.height
            while y >= 0 {   // anchor to the bottom so the baseline sits on a major line
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                i % 5 == 0 ? majorPath.addPath(p) : minorPath.addPath(p)
                y -= minor; i += 1
            }
            ctx.stroke(minorPath, with: .color(Theme.ecgGridMinor), lineWidth: 0.5)
            ctx.stroke(majorPath, with: .color(Theme.ecgGridMajor), lineWidth: 0.8)
        }
        .accessibilityHidden(true)
    }
}

/// Monitor-style sweep at a given heart rate. `flatline` keeps the sweep moving over a flat trace,
/// a monitor with nobody on it.
struct ECGMonitor: View {
    var bpm: Double = 104
    var color: Color = Theme.accent
    var stElevation = false
    var flatline = false
    var height: CGFloat = 40

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paper = scheme == .light
        let color = paper ? Theme.text : color      // paper ECGs are printed in black ink
        let beats = ECG.beatsPerSweep(bpm)
        let window = ECG.window(bpm)
        let shape = ECGShape(beats: flatline ? 0 : beats, stElevation: stElevation)
        let style = StrokeStyle(lineWidth: ECG.lineWidth, lineCap: .round, lineJoin: .round)

        GeometryReader { geo in
            let w = geo.size.width
            let tailW = w * ECG.tail
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let head = CGFloat((t.truncatingRemainder(dividingBy: window)) / window) * w
                ZStack {
                    if paper { ECGPaperGrid() }
                    shape.stroke(color.opacity(paper ? 0.14 : 0.18), style: style)
                    shape.stroke(color, style: style)
                        .shadow(color: Theme.glow(color, 0.6), radius: 4)
                        .mask(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                // Tail behind the head, plus its wrapped remainder on the right edge.
                                ForEach([head - tailW, head - tailW + w], id: \.self) { start in
                                    LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: tailW)
                                        .offset(x: start)
                                }
                            }
                            .frame(width: w, alignment: .leading)
                        }
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

/// Tab-screen large title (with optional trailing control). Shared by the tabs so titles sit at the same height.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(title: String) { self.init(title: title) { EmptyView() } }
}

/// Fades a horizontally scrolling row out at its trailing edge so it reads as scrollable.
struct TrailingFade: ViewModifier {
    var width: CGFloat = 28
    func body(content: Content) -> some View {
        content.mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: width)
            }
        )
    }
}

extension View {
    func trailingFade(_ width: CGFloat = 28) -> some View { modifier(TrailingFade(width: width)) }
}

// MARK: - Liquid Glass

/* Every button in the app is Liquid Glass, tinted with its main colour, with white text and icons.
 * iOS 26+: interactive glass (flexes and shimmers under the finger).
 * Earlier iOS: a solid fill of the same colour, so text stays white and readable. */

enum GLASS {
    static let tint = 1.0          // tint strength: the colour reads clearly, glass still shows
    static let disabled = 0.45
    static let highlight = 0.16    // how much lighter the top of each button's gradient is
}

extension View {
    /// Tinted interactive Liquid Glass in any shape; solid fill before iOS 26.
    @ViewBuilder
    func glassFill<S: Shape>(_ tint: Color, in shape: S, strength: Double = GLASS.tint, interactive: Bool = true) -> some View {
        // The colour lives in a vivid gradient *under* clear glass, so the glass adds shine and
        // depth without washing the colour out (tinted glass blends it toward grey).
        let fill = ZStack {
            shape.fill(tint.opacity(strength))
            shape.fill(LinearGradient(colors: [.white.opacity(GLASS.highlight), .clear], startPoint: .top, endPoint: .bottom))
        }
        if #available(iOS 26, *) {
            self.glassEffect(.clear.interactive(interactive), in: shape)
                .background { fill }
        } else {
            self.background { fill }
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }

    func glassCircle(tint: Color) -> some View { glassFill(tint, in: Circle()) }
    func glassCapsule(tint: Color) -> some View { glassFill(tint, in: Capsule()) }
}

/// Kept for existing call sites; identical to PrimaryButtonStyle.
typealias GlassPrimaryButtonStyle = PrimaryButtonStyle
