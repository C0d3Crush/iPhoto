import Foundation

struct Preset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var author: String?
    var adjustments: AdjustmentState

    // File format version for forward-compatibility
    var formatVersion: Int = 1
}

// MARK: - Built-in Film Looks

extension Preset {
    static let builtIn: [Preset] = [
        chrome, schwarz, velvet, nostalgie, kino, morgen
    ]

    // Muted, slightly cool, cinematic — Classic Chrome feel
    static let chrome = Preset(
        id: UUID(uuidString: "00000000-0001-0000-0000-000000000000")!,
        name: "Chrome",
        author: "iPhoto",
        adjustments: AdjustmentState(
            contrast: 1.08, saturation: 0.75, warmth: -0.08, clarity: 0.08
        )
    )

    // Monochrome, high contrast — Acros feel
    static let schwarz = Preset(
        id: UUID(uuidString: "00000000-0002-0000-0000-000000000000")!,
        name: "Schwarz",
        author: "iPhoto",
        adjustments: AdjustmentState(
            contrast: 1.25, saturation: 0.0, clarity: 0.15, texture: 0.10
        )
    )

    // Vivid, warm, punchy — Velvia feel
    static let velvet = Preset(
        id: UUID(uuidString: "00000000-0003-0000-0000-000000000000")!,
        name: "Velvet",
        author: "iPhoto",
        adjustments: AdjustmentState(
            exposure: 0.10, contrast: 1.15, saturation: 1.45,
            warmth: 0.08, clarity: 0.10
        )
    )

    // Faded, warm, analog — Classic Neg feel
    static let nostalgie = Preset(
        id: UUID(uuidString: "00000000-0004-0000-0000-000000000000")!,
        name: "Nostalgie",
        author: "iPhoto",
        adjustments: AdjustmentState(
            brightness: 0.04, contrast: 0.88, saturation: 0.82, warmth: 0.14
        )
    )

    // Flat, cinematic, low saturation — Eterna feel
    static let kino = Preset(
        id: UUID(uuidString: "00000000-0005-0000-0000-000000000000")!,
        name: "Kino",
        author: "iPhoto",
        adjustments: AdjustmentState(
            brightness: 0.02, contrast: 0.82, saturation: 0.72, warmth: 0.05
        )
    )

    // Warm golden hour
    static let morgen = Preset(
        id: UUID(uuidString: "00000000-0006-0000-0000-000000000000")!,
        name: "Morgen",
        author: "iPhoto",
        adjustments: AdjustmentState(
            exposure: 0.15, brightness: 0.03, saturation: 1.10, warmth: 0.25
        )
    )
}
