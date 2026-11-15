#if DEBUG
import UIKit

extension ScanImage {
    /// A drawn stand-in film for `-screen reading-room` (no real image ships in the app). Written to
    /// the temp folder once and loaded by file URL, so the screen goes through the same loading path.
    static func debugSample() -> ScanImage? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("debug-film.png")
        if !FileManager.default.fileExists(atPath: file.path) {
            let size = CGSize(width: 1024, height: 1024)
            let png = UIGraphicsImageRenderer(size: size).pngData { ctx in
                let cg = ctx.cgContext
                UIColor(white: 0.04, alpha: 1).setFill()
                cg.fill(CGRect(origin: .zero, size: size))
                let space = CGColorSpaceCreateDeviceGray()
                for (x, alpha) in [(340.0, 0.30), (690.0, 0.36)] {
                    let colors = [UIColor(white: 0.32, alpha: alpha * 2).cgColor, UIColor(white: 0.05, alpha: 0).cgColor] as CFArray
                    if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                        cg.drawRadialGradient(g, startCenter: CGPoint(x: x, y: 500), startRadius: 0,
                                              endCenter: CGPoint(x: x, y: 500), endRadius: 300, options: [])
                    }
                }
                UIColor(white: 0.72, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 492, y: 120, width: 40, height: 780), cornerRadius: 20).fill()
                UIColor(white: 0.80, alpha: 0.55).setFill()
                UIBezierPath(ovalIn: CGRect(x: 470, y: 520, width: 230, height: 210)).fill()
                UIColor(white: 0.86, alpha: 0.35).setFill()
                UIBezierPath(ovalIn: CGRect(x: 200, y: 610, width: 170, height: 140)).fill()
            }
            try? png.write(to: file)
        }
        guard let source = URL(string: "https://nihcc.app.box.com/v/ChestXray-NIHCC") else { return nil }
        return ScanImage(url: file, credit: "NIH Clinical Center",
                         citation: "Wang X, Peng Y, Lu L, Lu Z, Bagheri M, Summers RM. ChestX-ray8: Hospital-scale Chest X-ray Database and Benchmarks on Weakly-Supervised Classification and Localization of Common Thorax Diseases. IEEE CVPR 2017.",
                         sourceURL: source)
    }
}
#endif
