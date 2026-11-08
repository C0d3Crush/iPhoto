import SwiftUI
import AppKit

// Übersicht ähnlicher Bilder (pHash-Cluster, z.B. Belichtungsreihen).
// Anders als DuplicatesView geht es hier nicht um exakte Duplikate: der Nutzer
// wählt aus jedem Cluster das beste Bild — Rest optional löschen.
//
// v1.9.2: Klick auf ein Tile öffnet die Gruppe im Haupt-Viewer (nav = .similarGroup(idx)),
// nicht mehr eine separate Lightbox. Pfeiltasten iterieren dann automatisch nur
// innerhalb der Gruppe, weil visibleDocuments auf sie gefiltert wird.
struct SimilarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var pickOverrides: [String: Int] = [:]

    // `quality.similarGroups` speichert Snapshots von ImageDocument (Value-Type):
    // wenn Thumbnails erst nach dem Grouping fertig werden, hätten die Snapshots
    // weiterhin thumbnailImage == nil. Frisch aus der Collection auflösen —
    // Dictionary-Lookup O(N) einmal, O(1) pro Tile.
    private var groups: [[ImageDocument]] {
        let byID = Dictionary(viewModel.collection.documents.map { ($0.id, $0) },
                              uniquingKeysWith: { a, _ in a })
        return viewModel.quality.similarGroups
            .map { grp in grp.compactMap { byID[$0.id] } }
            .filter { $0.count > 1 }
    }

    var body: some View {
        content
            .onAppear {
                // Sicherstellen, dass Thumbnails der aktuell sichtbaren Docs geladen sind.
                viewModel.loadThumbnails()
            }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                            SimilarGroupCard(
                                group: group,
                                pickIndex: resolvedPickIndex(groupIdx: idx, group: group),
                                onPickChange: { newIdx in pickOverrides[groupKey(group)] = newIdx },
                                onTileTap: { tileIdx in openInMainViewer(groupIdx: idx, tileIdx: tileIdx, group: group) },
                                onTrashRest: { trashRest(idx: idx, group: group) }
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
                Text("Ähnliche Bilder")
                    .font(.title2).fontWeight(.semibold)
                if groups.isEmpty {
                    Text("Keine ähnlichen Bilder gefunden")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    let total = groups.reduce(0) { $0 + $1.count }
                    Text("\(groups.count) \(groups.count == 1 ? "Gruppe" : "Gruppen") · \(total) Bilder · Klick öffnet die Gruppe im Viewer")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Neu gruppieren") { viewModel.detectSimilarImages() }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Keine Cluster")
                .font(.title3).fontWeight(.medium)
            Text("Es wurden keine visuell ähnlichen Bilder erkannt. Ähnlichkeit basiert auf pHash — Belichtungsreihen und Serienaufnahmen sollten hier landen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Jetzt gruppieren") { viewModel.detectSimilarImages() }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupKey(_ group: [ImageDocument]) -> String {
        group.map { $0.id.uuidString }.sorted().joined(separator: ",")
    }

    private func resolvedPickIndex(groupIdx: Int, group: [ImageDocument]) -> Int {
        let raw = pickOverrides[groupKey(group)] ?? Self.recommendedPickIndex(in: group)
        return min(raw, group.count - 1)
    }

    // Heuristik für Erstauswahl: RAW bevorzugen, dann größte Datei (oft die beste Aufnahme).
    static func recommendedPickIndex(in group: [ImageDocument]) -> Int {
        if let idx = group.firstIndex(where: { $0.isRAW }) { return idx }
        var bestIdx = 0
        var bestSize: Int64 = -1
        for (idx, doc) in group.enumerated() {
            if doc.fileSize > bestSize { bestSize = doc.fileSize; bestIdx = idx }
        }
        return bestIdx
    }

    // Öffnet den geklickten Doc im Haupt-Viewer und scoped visibleDocuments auf die
    // Gruppe — Pfeiltasten iterieren so nur durch diese Similar-Cluster, exakt wie
    // in einem Album.
    private func openInMainViewer(groupIdx: Int, tileIdx: Int, group: [ImageDocument]) {
        let doc = group[tileIdx]
        guard let colIdx = viewModel.collection.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        viewModel.navSelection = .similarGroup(groupIdx)
        viewModel.selectDocument(at: colIdx)
    }

    private func trashRest(idx: Int, group: [ImageDocument]) {
        let keep = resolvedPickIndex(groupIdx: idx, group: group)
        let toTrash = group.enumerated().filter { $0.offset != keep }.map { $0.element }
        viewModel.moveToAppTrash(toTrash)
        pickOverrides.removeValue(forKey: groupKey(group))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.detectSimilarImages()
        }
    }
}

private struct SimilarGroupCard: View {
    let group: [ImageDocument]
    let pickIndex: Int
    let onPickChange: (Int) -> Void
    let onTileTap: (Int) -> Void
    let onTrashRest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(group.count) ähnliche Bilder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Rest in Papierkorb") { onTrashRest() }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(PlainButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(group.enumerated()), id: \.element.id) { docIdx, doc in
                        SimilarTile(
                            doc: doc,
                            isPick: docIdx == pickIndex,
                            onTap: { onTileTap(docIdx) },
                            onPick: { onPickChange(docIdx) }
                        )
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

private struct SimilarTile: View {
    let doc: ImageDocument
    let isPick: Bool
    let onTap: () -> Void
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 105)
                            .clipped()
                    } else {
                        Color.secondary.opacity(0.15)
                            .frame(width: 140, height: 105)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.6)
                            )
                    }
                }
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isPick ? Color.green : Color.clear, lineWidth: 2)
                )
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

                if isPick {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white).padding(2))
                        .padding(5)
                        .allowsHitTesting(false)
                }
            }

            Text(doc.filename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(doc.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            if doc.isRAW {
                Text("RAW")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(3)
            }

            Button(isPick ? "★ Beste" : "Als Beste wählen") {
                if !isPick { onPick() }
            }
            .font(.system(size: 9))
            .foregroundColor(isPick ? .green : .accentColor)
            .buttonStyle(PlainButtonStyle())
            .disabled(isPick)
        }
        .frame(width: 140)
    }
}
