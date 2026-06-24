import SwiftUI

struct CurvesView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var activeIdx: Int? = nil
    @State private var channel: Channel = .rgb

    enum Channel: String, CaseIterable { case rgb = "RGB", r = "R", g = "G", b = "B" }

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

    private var currentPoints: [CGPoint] {
        switch channel {
        case .rgb: return viewModel.adjCurvePoints
        case .r:   return viewModel.adjCurveR
        case .g:   return viewModel.adjCurveG
        case .b:   return viewModel.adjCurveB
        }
    }

    private func setPoints(_ pts: [CGPoint]) {
        switch channel {
        case .rgb: viewModel.adjCurvePoints = pts
        case .r:   viewModel.adjCurveR = pts
        case .g:   viewModel.adjCurveG = pts
        case .b:   viewModel.adjCurveB = pts
        }
    }

    private var channelColor: Color {
        channelColorFor(channel)
    }

    private func channelColorFor(_ ch: Channel) -> Color {
        switch ch {
        case .rgb: return .white
        case .r:   return Color(red: 1,   green: 0.3, blue: 0.3)
        case .g:   return Color(red: 0.3, green: 0.9, blue: 0.4)
        case .b:   return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Channel picker
            HStack(spacing: 4) {
                ForEach(Channel.allCases, id: \.self) { ch in
                    let isActive = channel == ch
                    Button(ch.rawValue) { channel = ch }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(isActive ? channelColorFor(ch) : Color(NSColor.secondaryLabelColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Color.black
                    grid(in: size)
                    diagonal(in: size)
                    curvePath(in: size)
                        .stroke(channelColor, lineWidth: 1.5)
                    ForEach(0..<5) { i in
                        controlPoint(i, in: size)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            if activeIdx == nil {
                                activeIdx = nearestPoint(to: val.startLocation, in: size)
                            }
                            guard let idx = activeIdx else { return }
                            var pts = currentPoints
                            let norm = normalize(val.location, in: size)
                            let x: CGFloat
                            if idx == 0 { x = 0 }
                            else if idx == 4 { x = 1 }
                            else { x = norm.x.clamped(pts[idx-1].x + 0.01, pts[idx+1].x - 0.01) }
                            pts[idx] = CGPoint(x: x, y: norm.y.clamped(0, 1))
                            setPoints(pts)
                        }
                        .onEnded { _ in activeIdx = nil }
                )
                .cornerRadius(4)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button("S-Kurve") { setPoints(CurvesView.sCurvePoints) }
                Button("Zurücksetzen") { setPoints(CurvesView.defaultPoints) }
                    .disabled(isDefault)
            }
            .buttonStyle(BorderlessButtonStyle())
            .font(.caption)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Sub-views

    private func grid(in size: CGSize) -> some View {
        Path { path in
            for i in 1..<4 {
                let x = size.width * CGFloat(i) / 4
                let y = size.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
    }

    private func diagonal(in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: 0))
        }
        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
    }

    private func curvePath(in size: CGSize) -> Path {
        let lut = Self.evaluateSpline(currentPoints)
        return Path { path in
            for (i, y) in lut.enumerated() {
                let pt = canvasPoint(CGPoint(x: CGFloat(i) / 255, y: y), in: size)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
    }

    @ViewBuilder
    private func controlPoint(_ i: Int, in size: CGSize) -> some View {
        let pt = canvasPoint(currentPoints[i], in: size)
        Circle()
            .fill(activeIdx == i ? Color.yellow : channelColor)
            .frame(width: 10, height: 10)
            .position(pt)
    }

    // MARK: - Helpers

    private func canvasPoint(_ norm: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: norm.x * size.width, y: (1 - norm.y) * size.height)
    }

    private func normalize(_ pt: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: (pt.x / size.width).clamped(0, 1),
                y: (1 - pt.y / size.height).clamped(0, 1))
    }

    private func nearestPoint(to location: CGPoint, in size: CGSize) -> Int {
        let pts = currentPoints
        var bestIdx = 0
        var bestDist = CGFloat.infinity
        for (i, p) in pts.enumerated() {
            let cp = canvasPoint(p, in: size)
            let d = hypot(location.x - cp.x, location.y - cp.y)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestDist < 24 ? bestIdx : -1
    }

    private var isDefault: Bool {
        let d = CurvesView.defaultPoints
        return zip(currentPoints, d).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
    }

    // MARK: - Spline

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
                m[i] = tau * alpha * d[i]
                m[i+1] = tau * beta * d[i]
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
            return v.clamped(0, 1)
        }
    }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(hi, Swift.max(lo, self)) }
}
