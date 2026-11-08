import SwiftUI
import AppKit

struct DuplicatesView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var keepOverrides: [String: Int] = [:]

    private var groups: [[ImageDocument]] { viewModel.quality.duplicateGroups }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                            DuplicateGroupCard(
                                group: group,
                                keepIndex: resolvedKeepIndex(groupIdx: idx, group: group),
                                onKeepChange: { newIdx in keepOverrides[groupKey(group)] = newIdx },
                                onExecute: { executeGroup(idx: idx, group: group) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duplikate")
                    .font(.title2).fontWeight(.semibold)
                if groups.isEmpty {
                    Text("Keine Duplikate gefunden")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    let del = groups.enumerated().reduce(0) { $0 + $1.element.count - 1 }
                    Text("\(groups.count) \(groups.count == 1 ? "Gruppe" : "Gruppen") · \(del) \(del == 1 ? "Datei" : "Dateien") zum Löschen vorgeschlagen")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Neu scannen") { viewModel.detectDuplicates() }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            if !groups.isEmpty {
                Button("Alle ausführen") { executeAll() }
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("Keine Duplikate")
                .font(.title3).fontWeight(.medium)
            Text("Alle Bilder haben einen eindeutigen Aufnahmezeitpunkt und eine eindeutige Dateigröße.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Neu scannen") { viewModel.detectDuplicates() }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupKey(_ group: [ImageDocument]) -> String {
        group.map { $0.id.uuidString }.sorted().joined(separator: ",")
    }

    private func resolvedKeepIndex(groupIdx: Int, group: [ImageDocument]) -> Int {
        let raw = keepOverrides[groupKey(group)] ?? Self.recommendedKeepIndex(in: group)
        return min(raw, group.count - 1)
    }

    static func recommendedKeepIndex(in group: [ImageDocument]) -> Int {
        if let idx = group.firstIndex(where: { $0.isRAW }) { return idx }
        let copyWords = ["kopie", " copy", "backup", "duplicate", " 2.", "(2)", "(1)"]
        for (idx, doc) in group.enumerated() {
            let lower = doc.url.path.lowercased()
            if !copyWords.contains(where: { lower.contains($0) }) { return idx }
        }
        if let idx = group.indices.min(by: { group[$0].url.path.count < group[$1].url.path.count }) {
            return idx
        }
        return 0
    }

    private func executeGroup(idx: Int, group: [ImageDocument]) {
        let keep = resolvedKeepIndex(groupIdx: idx, group: group)
        let toTrash = group.enumerated().filter { $0.offset != keep }.map { $0.element }
        viewModel.moveToAppTrash(toTrash)
        keepOverrides.removeValue(forKey: groupKey(group))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.detectDuplicates()
        }
    }

    private func executeAll() {
        var toTrash: [ImageDocument] = []
        for (idx, group) in groups.enumerated() {
            let keep = resolvedKeepIndex(groupIdx: idx, group: group)
            toTrash.append(contentsOf: group.enumerated().filter { $0.offset != keep }.map { $0.element })
        }
        viewModel.moveToAppTrash(toTrash)
        keepOverrides = [:]
        viewModel.quality.duplicateGroups = []
    }
}

private struct DuplicateGroupCard: View {
    let group: [ImageDocument]
    let keepIndex: Int
    let onKeepChange: (Int) -> Void
    let onExecute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let date = group.first?.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Ausführen") { onExecute() }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(PlainButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(group.enumerated()), id: \.element.id) { docIdx, doc in
                        DocTile(doc: doc, isKeep: docIdx == keepIndex) {
                            onKeepChange(docIdx)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
    }
}

private struct DocTile: View {
    let doc: ImageDocument
    let isKeep: Bool
    let onFlip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 96)
                            .clipped()
                    } else {
                        Color.secondary.opacity(0.15)
                            .frame(width: 130, height: 96)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }
                }
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isKeep ? Color.green : Color.red.opacity(0.65), lineWidth: 2)
                )

                Image(systemName: isKeep ? "checkmark.circle.fill" : "trash.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(isKeep ? .green : .red)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(5)
            }

            Text(doc.filename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text(doc.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)

            if doc.isRAW {
                Text("RAW")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(3)
            }

            Button(isKeep ? "✓ Behalten" : "Stattdessen behalten") {
                if !isKeep { onFlip() }
            }
            .font(.system(size: 9))
            .foregroundColor(isKeep ? .green : .accentColor)
            .buttonStyle(PlainButtonStyle())
            .disabled(isKeep)
        }
        .frame(width: 130)
    }
}
