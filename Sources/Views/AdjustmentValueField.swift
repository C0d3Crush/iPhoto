import SwiftUI

/// Editierbares Zahlenfeld neben einem Anpassungs-Regler.
/// Zeigt den formatierten Wert an; Klick + Eingabe + Enter setzt den Wert (auf den Bereich begrenzt).
struct AdjustmentValueField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    /// Anzeige-Skalierung (z.B. 100 für Prozent-Darstellung eines 0...1-Werts)
    var displayScale: Double = 1
    var font: Font = .caption.monospacedDigit()

    @State private var text: String = ""
    @State private var isEditing = false

    var body: some View {
        TextField("", text: $text, onEditingChanged: { editing in
            if editing {
                isEditing = true
            } else {
                commit()
                isEditing = false
            }
        }, onCommit: commit)
        .font(font)
        .multilineTextAlignment(.trailing)
        .textFieldStyle(PlainTextFieldStyle())
        .frame(width: 68)
        .onAppear { text = formattedValue }
        .onChange(of: value) { _ in
            if !isEditing { text = formattedValue }
        }
    }

    private var formattedValue: String {
        String(format: format, value * displayScale)
    }

    private func commit() {
        // Einheiten/Sonstiges entfernen, Komma als Dezimaltrenner akzeptieren
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-+".contains($0) }
        if let parsed = Double(cleaned) {
            let newValue = parsed / displayScale
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
        text = formattedValue
    }
}
