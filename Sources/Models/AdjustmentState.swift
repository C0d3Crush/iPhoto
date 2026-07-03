import CoreGraphics

struct AdjustmentState: Codable, Equatable {
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
    var cropRect:         CGRect             = CGRect(x: 0, y: 0, width: 1, height: 1)
    var rotation:         Double             = 0.0
    var turns:            Int               = 0    // 90°-Schritte im Uhrzeigersinn: 0=0°, 1=90°, 2=180°, 3=270°
    var localAdjustments: [LocalAdjustment] = []

    // Capture Sharpening
    var sharpenAmount: Double = 0       // 0–150 → USM intensity 0–1.5
    var sharpenRadius: Double = 1.0     // 0.5–3.0 px

    // Noise Reduction
    var lumaNoise:  Double = 0          // 0–100 → CINoiseReduction level 0–0.1
    var colorNoise: Double = 0          // 0–100 → chroma blur radius 0–25 px

    // Lens Corrections
    var vignetteAmount: Double = 0      // −100 (darken corners) … +100 (brighten corners)
    var distortion:     Double = 0      // −100 (barrel) … +100 (pincushion)
    var caAmount:       Double = 0      // 0–100 (chromatic aberration correction)

    init(exposure: Double = 0, brightness: Double = 0, contrast: Double = 1,
         saturation: Double = 1, warmth: Double = 0, tint: Double = 0,
         clarity: Double = 0, texture: Double = 0, dehaze: Double = 0,
         curvePoints: [CGPoint] = AdjustmentState.defaultCurve,
         curveR: [CGPoint] = AdjustmentState.defaultCurve,
         curveG: [CGPoint] = AdjustmentState.defaultCurve,
         curveB: [CGPoint] = AdjustmentState.defaultCurve,
         cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
         rotation: Double = 0,
         localAdjustments: [LocalAdjustment] = []) {
        self.exposure = exposure; self.brightness = brightness; self.contrast = contrast
        self.saturation = saturation; self.warmth = warmth; self.tint = tint
        self.clarity = clarity; self.texture = texture; self.dehaze = dehaze
        self.curvePoints = curvePoints; self.curveR = curveR
        self.curveG = curveG; self.curveB = curveB
        self.cropRect = cropRect; self.rotation = rotation
        self.localAdjustments = localAdjustments
    }

    static let defaultCurve: [CGPoint] = [
        CGPoint(x: 0.0,  y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5,  y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0,  y: 1.0)
    ]
}
