import CoreGraphics
import Testing
@testable import Rounds

/// The reading room's zoom limits: never below fit, never past the max, never dragged off the film.
struct ScanZoomTests {
    @Test(arguments: [
        (1.0, 0.5, 1.0),   // pinch in from fit stays at fit
        (1.0, 2.0, 2.0),
        (3.0, 3.0, ScanZoom.maxScale),
        (2.0, 0.25, 1.0),
    ] as [(CGFloat, CGFloat, CGFloat)])
    func pinchStaysInRange(base: CGFloat, magnification: CGFloat, expected: CGFloat) {
        #expect(ScanZoom.scale(base, pinched: magnification) == expected)
    }

    @Test func noPanAtFit() {
        let frame = CGSize(width: 390, height: 500)
        #expect(ScanZoom.clamp(CGSize(width: 80, height: -40), scale: 1, film: frame, in: frame) == .zero)
    }

    @Test func panStopsAtTheFilmEdge() {
        let frame = CGSize(width: 400, height: 500)
        // A film filling the frame at 2× overflows by 200×250 each side.
        #expect(ScanZoom.clamp(CGSize(width: 900, height: -900), scale: 2, film: frame, in: frame) == CGSize(width: 200, height: -250))
        #expect(ScanZoom.clamp(CGSize(width: 50, height: 60), scale: 2, film: frame, in: frame) == CGSize(width: 50, height: 60))
    }

    @Test func letterboxedFilmCantPanIntoItsEmptyBand() {
        // A square 1024 px film in a 390×520 frame fits at 390×390, leaving 65 pt bands above and below.
        let frame = CGSize(width: 390, height: 520)
        let film = ScanZoom.fitted(CGSize(width: 1024, height: 1024), in: frame)
        #expect(film == CGSize(width: 390, height: 390))
        // At 1.2× the film is 468 tall: still inside 520, so no vertical pan at all.
        #expect(ScanZoom.clamp(CGSize(width: 0, height: 100), scale: 1.2, film: film, in: frame).height == 0)
        // At 2× it is 780 tall: 130 pt of overflow each way, not the 260 the frame alone would allow.
        #expect(ScanZoom.clamp(CGSize(width: 0, height: 500), scale: 2, film: film, in: frame).height == 130)
    }

    @Test func doubleTapTogglesFit() {
        let zoomed = ScanZoom().toggled()
        #expect(zoomed.scale == ScanZoom.doubleTapScale)
        #expect(zoomed.toggled() == ScanZoom())
        #expect(ScanZoom(scale: 1, offset: CGSize(width: 0, height: 0)).isFit)
    }
}
