import Foundation

// MARK: - ELO Rating

/// Standard-ELO-Berechnung für den Bildvergleich (Duell-Modus).
/// Alle Bilder starten bei `initial` (1500). Nach jedem Duell werden beide ELOs
/// aktualisiert; der K-Faktor bestimmt, wie stark einzelne Ergebnisse wiegen.
enum EloRating {
    static let initial: Double = 1500
    static let baseK: Double = 32

    /// Erwartete Punktzahl für `selfRating` gegen `opponent` (0..1).
    static func expected(_ selfRating: Double, _ opponent: Double) -> Double {
        1.0 / (1.0 + pow(10, (opponent - selfRating) / 400))
    }

    /// K-Faktor mit sanftem Decay: neue Bilder bewegen sich schnell (K=40),
    /// nach ~30 Matches stabilisiert sich der Wert bei K=16. Verhindert, dass
    /// gut eingespielte Bilder durch ein einziges Duell stark schwanken.
    static func kFactor(matches: Int) -> Double {
        let decayed = 40.0 - Double(matches) * 0.8
        return max(16, min(40, decayed))
    }

    /// Aktualisiert beide ELOs nach einem Duell.
    /// `leftScore`: 1.0 (links gewinnt), 0.5 (Unentschieden), 0.0 (rechts gewinnt).
    /// Rückgabe: neue ELOs für links und rechts.
    static func update(leftRating: Double, leftMatches: Int,
                       rightRating: Double, rightMatches: Int,
                       leftScore: Double) -> (left: Double, right: Double) {
        let expLeft = expected(leftRating, rightRating)
        let expRight = 1.0 - expLeft
        let kL = kFactor(matches: leftMatches)
        let kR = kFactor(matches: rightMatches)
        let newLeft = leftRating + kL * (leftScore - expLeft)
        let newRight = rightRating + kR * ((1.0 - leftScore) - expRight)
        return (newLeft, newRight)
    }
}
