import Foundation
import CoreGraphics

struct LocalDelta: Codable, Equatable {
    var exposure:   Double = 0.0
    var brightness: Double = 0.0
    var contrast:   Double = 1.0
    var saturation: Double = 1.0
    var warmth:     Double = 0.0
    var tint:       Double = 0.0

    var isNeutral: Bool {
        exposure == 0 && brightness == 0 && contrast == 1.0
        && saturation == 1.0 && warmth == 0 && tint == 0
    }
}

enum MaskShape: Equatable {
    // Normalized 0–1 coordinates, top-left origin (SwiftUI convention)
    case linearGradient(startX: Double, startY: Double, endX: Double, endY: Double)
    case radialGradient(centerX: Double, centerY: Double, radius: Double, feather: Double)
}

extension MaskShape: Codable {
    private enum CodingKeys: String, CodingKey { case type, startX, startY, endX, endY, centerX, centerY, radius, feather }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .linearGradient(let sx, let sy, let ex, let ey):
            try c.encode("linear", forKey: .type)
            try c.encode(sx, forKey: .startX); try c.encode(sy, forKey: .startY)
            try c.encode(ex, forKey: .endX);   try c.encode(ey, forKey: .endY)
        case .radialGradient(let cx, let cy, let r, let f):
            try c.encode("radial", forKey: .type)
            try c.encode(cx, forKey: .centerX); try c.encode(cy, forKey: .centerY)
            try c.encode(r, forKey: .radius);   try c.encode(f, forKey: .feather)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try c.decode(String.self, forKey: .type)
        if type_ == "linear" {
            self = .linearGradient(
                startX: try c.decode(Double.self, forKey: .startX),
                startY: try c.decode(Double.self, forKey: .startY),
                endX:   try c.decode(Double.self, forKey: .endX),
                endY:   try c.decode(Double.self, forKey: .endY))
        } else {
            self = .radialGradient(
                centerX: try c.decode(Double.self, forKey: .centerX),
                centerY: try c.decode(Double.self, forKey: .centerY),
                radius:  try c.decode(Double.self, forKey: .radius),
                feather: try c.decode(Double.self, forKey: .feather))
        }
    }
}

struct LocalAdjustment: Codable, Identifiable, Equatable {
    var id:        UUID      = UUID()
    var label:     String    = ""
    var mask:      MaskShape
    var delta:     LocalDelta = LocalDelta()
    var inverted:  Bool      = false
    var intensity: Double    = 1.0  // 0–1 mask opacity
}
