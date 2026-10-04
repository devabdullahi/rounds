import SwiftUI

/// Draws an SVG path string as a SwiftUI shape. Used for animated line art (the ECG traces),
/// which needs real geometry to trim and sweep. Icons are image assets, not paths: see Icons.swift.
struct SVGShape: Shape {
    let d: String
    let viewBox: CGSize
    func path(in rect: CGRect) -> Path {
        var p = Path()
        SVGPath.append(d, to: &p)
        return p.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height))
    }
}

// MARK: - Minimal SVG path parser (M L H V C S Q T A Z, absolute and relative)

enum SVGPath {
    static func append(_ d: String, to path: inout Path) {
        var tokens = tokenize(d)[...]
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCtrl: CGPoint?

        func num() -> CGFloat {
            guard case .number(let v)? = tokens.first else { return 0 }
            tokens = tokens.dropFirst()
            return v
        }
        func flag() -> Bool { num() != 0 }
        func pt(_ rel: Bool) -> CGPoint {
            let x = num(), y = num()
            return rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }

        while let t = tokens.first {
            if case .command(let c) = t { cmd = c; tokens = tokens.dropFirst() }
            let rel = cmd.isLowercase
            switch cmd.uppercased().first! {
            case "M":
                cur = pt(rel); start = cur; path.move(to: cur); lastCtrl = nil
                cmd = rel ? "l" : "L"   // subsequent pairs are implicit lineto
            case "L": cur = pt(rel); path.addLine(to: cur); lastCtrl = nil
            case "H": let x = num(); cur.x = rel ? cur.x + x : x; path.addLine(to: cur); lastCtrl = nil
            case "V": let y = num(); cur.y = rel ? cur.y + y : y; path.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = pt(rel), c2 = pt(rel), e = pt(rel)
                path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pt(rel), e = pt(rel)
                path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "Q":
                let c = pt(rel), e = pt(rel)
                path.addQuadCurve(to: e, control: c); lastCtrl = c; cur = e
            case "T":
                let c = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let e = pt(rel)
                path.addQuadCurve(to: e, control: c); lastCtrl = c; cur = e
            case "A":
                let rx = num(), ry = num(); _ = num()
                let large = flag(), sweep = flag()
                let e = pt(rel)
                addArc(&path, from: cur, to: e, r: (rx + ry) / 2, large: large, sweep: sweep)
                cur = e; lastCtrl = nil
            case "Z":
                path.closeSubpath(); cur = start; lastCtrl = nil
                if case .number? = tokens.first { tokens = tokens.dropFirst() } // malformed guard
            default:
                tokens = tokens.dropFirst()
            }
        }
    }

    /// Circular SVG arc (Lucide never rotates or uses elliptical arcs).
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, r rIn: CGFloat, large: Bool, sweep: Bool) {
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let d2 = dx * dx + dy * dy
        guard d2 > 0, rIn > 0 else { path.addLine(to: p1); return }
        var r = rIn
        if d2 > r * r { r = sqrt(d2) }  // radius too small for the chord: scale up (SVG spec)
        let sign: CGFloat = large == sweep ? -1 : 1
        let coef = sign * sqrt(max(0, (r * r - d2) / d2))
        let cxp = coef * dy, cyp = -coef * dx
        let center = CGPoint(x: cxp + (p0.x + p1.x) / 2, y: cyp + (p0.y + p1.y) / 2)
        let a0 = atan2(p0.y - center.y, p0.x - center.x)
        let a1 = atan2(p1.y - center.y, p1.x - center.x)
        // SVG sweep=1 is the positive-angle direction, which Path calls clockwise: false.
        path.addArc(center: center, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: !sweep)
    }

    private enum Token { case command(Character), number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" {
                out.append(.command(c)); i += 1
            } else if c == "-" || c == "+" || c == "." || c.isNumber {
                var j = i
                var s = ""
                if chars[j] == "-" || chars[j] == "+" { s.append(chars[j]); j += 1 }
                var seenDot = false
                while j < chars.count {
                    let ch = chars[j]
                    if ch.isNumber { s.append(ch) }
                    else if ch == "." && !seenDot { seenDot = true; s.append(ch) }
                    else if (ch == "e" || ch == "E") { s.append(ch); if j + 1 < chars.count, chars[j + 1] == "-" || chars[j + 1] == "+" { j += 1; s.append(chars[j]) } }
                    else { break }
                    j += 1
                }
                out.append(.number(CGFloat(Double(s) ?? 0)))
                i = j
            } else {
                i += 1
            }
        }
        return out
    }
}
