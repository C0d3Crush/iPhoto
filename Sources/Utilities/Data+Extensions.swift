import Foundation

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) << 24
             | UInt32(self[offset + 1]) << 16
             | UInt32(self[offset + 2]) << 8
             | UInt32(self[offset + 3])
    }
}
