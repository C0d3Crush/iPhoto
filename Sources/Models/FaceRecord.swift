import Foundation
import CoreGraphics

struct FaceRecord: Identifiable {
    let id: String           // UUID string
    let imagePath: String
    var clusterID: String?   // FK → people.id, nil = unassigned
    let bbox: CGRect         // normalized, top-left origin (already flipped from Vision)
    let confidence: Float
    var embeddingData: Data? // 128 × Float32 = 512 bytes
}

struct PersonRecord: Identifiable {
    let id: String
    var name: String?
    var coverFaceID: String?
}
