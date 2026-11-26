import CoreGraphics

enum CurveMath {

    static let defaultPoints: [CGPoint] = [
        CGPoint(x: 0,    y: 0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5,  y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1,    y: 1)
    ]

    static let sCurvePoints: [CGPoint] = [
        CGPoint(x: 0,    y: 0),
        CGPoint(x: 0.25, y: 0.10),
        CGPoint(x: 0.5,  y: 0.5),
        CGPoint(x: 0.75, y: 0.90),
        CGPoint(x: 1,    y: 1)
    ]

    static func isDefault(_ pts: [CGPoint]) -> Bool {
        zip(pts, defaultPoints).allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
    }

    // Monotone Hermite spline → 256-entry LUT in [0,1].
    static func evaluateSpline(_ pts: [CGPoint]) -> [CGFloat] {
        let n = pts.count
        guard n >= 2 else { return [CGFloat](repeating: 0, count: 256) }

        var d = [CGFloat](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            let dx = pts[i+1].x - pts[i].x
            d[i] = dx > 0 ? (pts[i+1].y - pts[i].y) / dx : 0
        }

        var m = [CGFloat](repeating: 0, count: n)
        m[0] = d[0]; m[n-1] = d[n-2]
        for i in 1..<(n-1) { m[i] = (d[i-1] + d[i]) / 2 }

        for i in 0..<(n-1) {
            guard d[i] != 0 else { m[i] = 0; m[i+1] = 0; continue }
            let alpha = m[i] / d[i], beta = m[i+1] / d[i]
            let h = alpha * alpha + beta * beta
            if h > 9 {
                let tau = 3 / sqrt(h)
                m[i]   = tau * alpha * d[i]
                m[i+1] = tau * beta  * d[i]
            }
        }

        return (0..<256).map { s in
            let x = CGFloat(s) / 255
            var seg = n - 2
            for i in 0..<(n-1) { if x <= pts[i+1].x { seg = i; break } }
            let x0 = pts[seg].x, y0 = pts[seg].y
            let x1 = pts[seg+1].x, y1 = pts[seg+1].y
            let dx = x1 - x0
            guard dx > 0 else { return y0 }
            let t = (x - x0) / dx
            let t2 = t*t, t3 = t2*t
            let v = (2*t3 - 3*t2 + 1)*y0 + (t3 - 2*t2 + t)*dx*m[seg]
                  + (-2*t3 + 3*t2)*y1 + (t3 - t2)*dx*m[seg+1]
            return max(0, min(1, v))
        }
    }
}
