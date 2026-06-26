import Foundation
import AppKit

struct HotPixelResult {
    let frameCount: Int
    let sensorWidth: Int
    let sensorHeight: Int
    let hotPixels: [(x: Int, y: Int, value: Float)]  // sorted by value desc
    let hotCount: Int
    let threshold: Float
    let darkMean: Float
    let darkStd: Float
    let grade: String
    let gradeLabel: String
    let clusterGrid: [[Int]]   // 20×20
    let sampleDistribution: [Float]  // up to 50k sampled values from mean frame

    var gradeColor: NSColor {
        switch grade {
        case "A": return NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        case "B": return NSColor(red: 0.5, green: 0.85, blue: 0.2, alpha: 1)
        case "C": return NSColor(red: 0.9, green: 0.8, blue: 0.0, alpha: 1)
        case "D": return NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)
        case "E": return NSColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1)
        default:  return NSColor(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)
        }
    }

    static func severity(_ count: Int) -> (String, String) {
        switch count {
        case ..<50:   return ("A", "Hervorragend")
        case ..<200:  return ("B", "Gut")
        case ..<500:  return ("C", "Akzeptabel")
        case ..<1500: return ("D", "Erhöht")
        case ..<5000: return ("E", "Kritisch")
        default:      return ("F", "Defekt")
        }
    }
}
