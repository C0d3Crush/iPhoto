import SwiftUI
import AppKit

struct CrashReportSheet: View {
    let report: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("iPhoto ist abgestürzt")
                    .font(.headline)
                Spacer()
            }

            Text("Beim letzten Start wurde iPhoto nicht sauber beendet. Hier ist der Log der letzten Session:")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .frame(minHeight: 300)

            HStack {
                Button("Schließen") {
                    isPresented = false
                }
                Spacer()
                Button("Speichern…") {
                    save()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 440)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["txt"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        panel.nameFieldStringValue = "iPhoto_Crash_\(formatter.string(from: Date())).txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? report.write(to: url, atomically: true, encoding: .utf8)
            isPresented = false
        }
    }
}
