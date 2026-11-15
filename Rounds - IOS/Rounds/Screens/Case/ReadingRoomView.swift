import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Reading room (going to the radiologist)
 *
 *    0ms   full-screen cover slides up; film area dark, spinner
 *    load  scan fades in over the spinner (250ms); 15s timeout → fail
 *  pinch   zoom follows the fingers, clamped fit…5×, no spring
 *  2-tap   fit ⇄ 2.5× on a spring; reset button fades in when zoomed
 *  fail    film area swaps to "The image didn't load" + Try again
 *
 * Reduce Motion: no springs, zoom and swaps jump to their end state.
 * ───────────────────────────────────────────────────────── */

private enum READING {
    static let filmShare: CGFloat = 0.62   // share of the screen height the film takes
    static let fade = Animation.easeOut(duration: 0.25)
    static let sheetRadius: CGFloat = 28
    /// Past this a report scrolls, so a long one can't push the film off screen.
    static let reportMaxHeight: CGFloat = 170
}

/// Where the film is: loading, on screen, or failed (dead link, offline).
private enum FilmPhase {
    case loading
    case loaded(UIImage)
    case failed
}

/// Going to the radiologist: the real teaching X-ray on top, zoomable, with the report underneath.
/// Always dark, like a reading room, whatever the app's appearance.
struct ReadingRoomView: View {
    let testName: String
    let result: TestResult
    /// Asks the server for a fresh image link (signed links expire); nil when it has none.
    let refresh: () async -> ScanImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scan: ScanImage?
    @State private var zoom = ScanZoom()
    @State private var phase = FilmPhase.loading
    /// Bumped by Try again; the load task restarts on each change and is cancelled when the screen closes.
    @State private var attempt = 0
    @State private var reportHeight: CGFloat = 0
    @State private var showingCredit = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                film
                    .frame(height: geo.size.height * READING.filmShare)
                    .frame(maxWidth: .infinity)
                topBar
                VStack { Spacer(); report }
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCredit) {
            if let scan { ScanCreditSheet(scan: scan) }
        }
        .task(id: attempt) {
            if attempt == 0 { scan = result.scan }
            await loadFilm(refreshing: attempt > 0)
        }
    }

    // MARK: Film

    @ViewBuilder
    private var film: some View {
        switch phase {
        case .loaded(let image):
            ZoomableScan(image: image, zoom: $zoom, reduceMotion: reduceMotion)
                .accessibilityLabel("\(testName), real teaching image")
                .accessibilityValue("Report: \(result.text)")
                .accessibilityHint("Pinch to zoom, double-tap to fit")
                .transition(.opacity)
        case .failed:
            failed
        case .loading:
            ProgressView().tint(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Loads the film; on failure asks the server for a fresh link once (signed links expire) and tries that.
    private func loadFilm(refreshing: Bool) async {
        phase = .loading
        if refreshing, let fresh = await refresh() { scan = fresh }
        guard !Task.isCancelled, let url = scan?.url, let image = try? await ScanLoader.image(at: url) else {
            if !Task.isCancelled { set(.failed) }
            return
        }
        if !Task.isCancelled { set(.loaded(image)) }
    }

    private func set(_ next: FilmPhase) {
        if reduceMotion { phase = next } else { withAnimation(READING.fade) { phase = next } }
    }

    /// The link expired or the network dropped: try the same link once more, then a fresh one.
    private var failed: some View {
        VStack(spacing: 14) {
            AppIcon(.images, size: 36).foregroundStyle(Theme.muted)
            Text("The image didn't load")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.dim)
            Button("Try again") {
                zoom = ScanZoom()
                attempt += 1
            }
            .buttonStyle(QuietButtonStyle(height: 44, fontSize: 15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            IconButton(glyph: .x, label: "Close", size: 20, quiet: true) { dismiss() }
            Spacer()
            Text("\(testName) · Radiology")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassFill(Theme.text.opacity(0.10), in: Capsule(), interactive: false)
            Spacer()
            IconButton(glyph: .arrowsIn, label: "Fit to screen", size: 20, quiet: true) {
                if reduceMotion { zoom = ScanZoom() } else { withAnimation(Springs.slide) { zoom = ScanZoom() } }
            }
            .opacity(zoom.isFit ? 0 : 1)
            .disabled(zoom.isFit)
            .animation(reduceMotion ? nil : READING.fade, value: zoom.isFit)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var reportText: some View {
        Text(result.text)
            .font(.system(size: 17))
            .lineSpacing(4)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var report: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Radiologist's report")
                Spacer()
                if result.isAbnormal {
                    Pill(text: "Abnormal", fg: Theme.warnText, bg: Theme.warnSoft)
                } else {
                    Pill(text: "Normal", fg: Theme.dim, bg: Theme.track)
                }
            }
            // Snug for a short report; a long one scrolls inside the cap instead of being cut off.
            ScrollView {
                reportText.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reportHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(reportHeight, READING.reportMaxHeight))
            if let scan {
                Button { showingCredit = true } label: {
                    HStack(spacing: 6) {
                        AppIcon(.info, size: 14)
                        Text("Real de-identified teaching image · \(scan.credit)")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("About this image")
            }
            Button("Back to the patient") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: READING.sheetRadius, topTrailingRadius: READING.sheetRadius, style: .continuous))
        .background(alignment: .bottom) { Theme.surface.frame(height: 60).offset(y: 50).ignoresSafeArea() }
    }
}
