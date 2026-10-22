import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Welcome to the team (after buying)
 *
 *    0ms   lanyard drops from above, pivoting at its top (1100ms):
 *            y -340 → +14 → -4 → 0, swinging -9° → 5° → -2.5° → 0
 *  700ms   a sheen sweeps once across the badge (1100ms)
 *  800ms   headline rises, y 12 → 0
 *  950ms   plan line and button rise
 * Reduce Motion: final state, no sheen.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let sheen = 0.7
    static let headline = 0.8
    static let rest = 0.95
}

/// The drop's keyframes: offset and swing at each point, as fractions of `duration`.
private enum LANYARD {
    static let duration = 1.1
    static let stops: [(at: Double, y: CGFloat, angle: Double)] = [
        (0, -340, -9), (0.55, 14, 5), (0.75, -4, -2.5), (1, 0, 0),
    ]
    static let sheenWidth: CGFloat = 70
    static let sheenDuration = 1.1
}

/// Where the lanyard is in its drop.
private struct DropPose {
    var y: CGFloat = LANYARD.stops[0].y
    var angle: Double = LANYARD.stops[0].angle
}

/// Shown once, right after a plan is bought: the student's Rounds ID badge on a lanyard, then
/// "Start my first shift" into the app.
struct WelcomeAboardView: View {
    let name: String?
    let year: SchoolYear?
    let goal: StudyGoal?
    let plan: ActivePlan?
    let onStart: () -> Void

    @State private var shown = false
    @State private var sheenAcross = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var planLine: String {
        guard let plan else { return "Your plan is active." }
        if plan.isTrial {
            return "Free until \(plan.periodEnd.formatted(.dateTime.month(.abbreviated).day())). We'll remind you the day before."
        }
        return "Rounds \(plan.period.name) is active."
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if reduceMotion {
                    lanyard
                } else {
                    lanyard.keyframeAnimator(initialValue: DropPose(), trigger: shown) { view, pose in
                        view.offset(y: shown ? pose.y : LANYARD.stops[0].y)
                            .rotationEffect(.degrees(shown ? pose.angle : LANYARD.stops[0].angle), anchor: .top)
                    } keyframes: { _ in
                        KeyframeTrack(\.y) {
                            for (prev, stop) in zip(LANYARD.stops, LANYARD.stops.dropFirst()) {
                                CubicKeyframe(stop.y, duration: (stop.at - prev.at) * LANYARD.duration)
                            }
                        }
                        KeyframeTrack(\.angle) {
                            for (prev, stop) in zip(LANYARD.stops, LANYARD.stops.dropFirst()) {
                                CubicKeyframe(stop.angle, duration: (stop.at - prev.at) * LANYARD.duration)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 16)
            VStack(spacing: 14) {
                Text(name.map { "Welcome to the team, \($0)" } ?? "Welcome to the team")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .rise(shown, at: TIMING.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(planLine)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .rise(shown, at: TIMING.rest)
                Button("Start my first shift", action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                    .rise(shown, at: TIMING.rest)
            }
            .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.heroMint
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 500).offset(y: -120)
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 340).offset(y: -120)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            shown = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: LANYARD.sheenDuration).delay(TIMING.sheen)) { sheenAcross = true }
        }
    }

    private var lanyard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 46) {
                strap(skew: 8)
                strap(skew: -8)
            }
            .frame(height: 118)
            // The clip, and the hook through the badge.
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.track)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.faint, lineWidth: 2))
                .frame(width: 46, height: 22)
                .padding(.top, -6)
            Path { p in   // a U, open at the top
                p.move(to: CGPoint(x: 1.5, y: 0))
                p.addLine(to: CGPoint(x: 1.5, y: 9))
                p.addQuadCurve(to: CGPoint(x: 8, y: 14.5), control: CGPoint(x: 1.5, y: 14.5))
                p.addLine(to: CGPoint(x: 14, y: 14.5))
                p.addQuadCurve(to: CGPoint(x: 20.5, y: 9), control: CGPoint(x: 20.5, y: 14.5))
                p.addLine(to: CGPoint(x: 20.5, y: 0))
            }
            .stroke(Theme.faint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 22, height: 16)
            .padding(.top, -2)
            badge.padding(.top, -4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Rounds badge", name, year?.label, goal?.label].compactMap { $0 }.joined(separator: ", "))
    }

    /// One side of the lanyard: a striped strap, slanted toward the clip.
    private func strap(skew degrees: Double) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.accent))
            var y: CGFloat = 22
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)), with: .color(Theme.accentFill))
                y += 24
            }
        }
        .frame(width: 18, height: 118)
        .transformEffect(CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(degrees * .pi / 180)), d: 1, tx: 0, ty: 0))
    }

    private var badge: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    AppIcon(.brandMark, size: 22)
                    Text("ROUNDS").font(.system(size: 16, weight: .heavy)).tracking(0.5)
                }
                Spacer()
                Text("STUDENT").font(.system(size: 11, weight: .heavy)).tracking(1.3).opacity(0.8)
            }
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(Theme.accent)

            VStack(spacing: 10) {
                // Sits half over the green band, like a photo on an ID.
                Text(initial)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.info)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Theme.info.opacity(0.18)))
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 4))
                    .padding(.top, -48)
                VStack(spacing: 2) {
                    Text(name ?? "Student doctor").font(.system(size: 24, weight: .bold)).tracking(-0.4)
                    Text([name == nil ? nil : "Student doctor", year?.label].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 8) {
                    field("PLAN", plan?.period.name ?? "Rounds")
                    field("FOCUS", goal?.label ?? "Every rotation")
                }
                .padding(.top, 4)
                barcode.padding(.top, 4)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 248)
        .background(Theme.surface)
        .overlay { sheen }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.text.opacity(0.22), radius: 25, y: 24)
    }

    /// The barcode along the bottom of the badge: a fixed pattern of thin and thick bars.
    private var barcode: some View {
        Canvas { ctx, size in
            let pattern: [(CGFloat, CGFloat)] = [(0, 2), (4, 1), (9, 3)]   // (x, width) every 14pt
            var x: CGFloat = 0
            while x < size.width {
                for (dx, w) in pattern where x + dx < size.width {
                    ctx.fill(Path(CGRect(x: x + dx, y: 0, width: w, height: size.height)), with: .color(Theme.text))
                }
                x += 14
            }
        }
        .frame(height: 30)
        .opacity(0.85)
        .accessibilityHidden(true)
    }

    /// One bright band that sweeps across the badge once.
    private var sheen: some View {
        GeometryReader { geo in
            LinearGradient(colors: [Theme.accentInk.opacity(0), Theme.accentInk.opacity(0.65), Theme.accentInk.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: LANYARD.sheenWidth)
                .transformEffect(CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(-18 * Double.pi / 180)), d: 1, tx: 0, ty: 0))
                .offset(x: sheenAcross ? geo.size.width + LANYARD.sheenWidth : -LANYARD.sheenWidth * 2)
        }
        .allowsHitTesting(false)
        .opacity(reduceMotion ? 0 : 1)
    }

    private var initial: String {
        name?.first.map { String($0).uppercased() } ?? "R"
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
