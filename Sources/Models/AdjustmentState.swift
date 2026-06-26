import CoreGraphics

struct AdjustmentState: Equatable {
    var exposure:    Double = 0.0
    var brightness:  Double = 0.0
    var contrast:    Double = 1.0
    var saturation:  Double = 1.0
    var warmth:      Double = 0.0
    var tint:        Double = 0.0
    var clarity:     Double = 0.0
    var texture:     Double = 0.0
    var dehaze:      Double = 0.0
    var curvePoints: [CGPoint] = AdjustmentState.defaultCurve
    var curveR:      [CGPoint] = AdjustmentState.defaultCurve
    var curveG:      [CGPoint] = AdjustmentState.defaultCurve
    var curveB:      [CGPoint] = AdjustmentState.defaultCurve
    var cropRect:    CGRect    = CGRect(x: 0, y: 0, width: 1, height: 1)
    var rotation:    Double    = 0.0

    static let defaultCurve: [CGPoint] = [
        CGPoint(x: 0.0,  y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5,  y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0,  y: 1.0)
    ]
}
