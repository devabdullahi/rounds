import Testing
@testable import Rounds

/// The line-draw timing for the admitting loader: draw, hold, then run off by the tail.
struct AnatomyLoaderTests {
    @Test("Each beat starts empty, holds fully drawn, and ends fully run off", arguments: [
        (0.0, 0.0, 0.0),
        (0.5, 0.0, 1.0),
        (0.74, 0.0, 1.0),
        (1.0, 1.0, 1.0),
    ])
    func trim(phase: Double, from: Double, to: Double) {
        let (f, t) = AnatomyLoader.trim(phase)
        #expect(abs(Double(f) - from) < 0.001)
        #expect(abs(Double(t) - to) < 0.001)
    }

    @Test func drawingGrowsAndRunOffShrinks() {
        let early = AnatomyLoader.trim(0.1).1, later = AnatomyLoader.trim(0.3).1
        #expect(early < later)
        let leaving = AnatomyLoader.trim(0.8).0, gone = AnatomyLoader.trim(0.95).0
        #expect(leaving < gone)
    }

    @Test func labelFadesInAndOutWithTheLine() {
        #expect(AnatomyLoader.labelOpacity(0) == 0)
        #expect(AnatomyLoader.labelOpacity(0.5) == 1)
        #expect(AnatomyLoader.labelOpacity(1) == 0)
    }
}
