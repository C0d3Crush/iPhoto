import SwiftUI
import AppKit

// Übersicht ähnlicher Bilder (pHash-Cluster, z.B. Belichtungsreihen).
// Anders als DuplicatesView geht es hier nicht um exakte Duplikate: der Nutzer
// wählt aus jedem Cluster das beste Bild — Rest optional löschen.
struct SimilarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var pickOverrides: [Int: Int] = [:]
    @State private var lightboxGroupIdx: Int? = nil
    @State private var lightboxTileIdx: Int = 0

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
        ZStack {
            content
            if let gIdx = lightboxGroupIdx, gIdx < groups.count {
                SimilarLightbox(
                    group: groups[gIdx],
                    currentIdx: $lightboxTileIdx,
                    pickIdx: resolvedPickIndex(groupIdx: gIdx, group: groups[gIdx]),
                    onPickChange: { newIdx in pickOverrides[gIdx] = newIdx },
                    onClose: { lightboxGroupIdx = nil }
                )
                .transition(.opacity)
            }
        }
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
                                onPickChange: { newIdx in pickOverrides[idx] = newIdx },
                                onTileTap: { tileIdx in
                                    lightboxTileIdx = tileIdx
                                    lightboxGroupIdx = idx
                                },
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
                    Text("\(groups.count) \(groups.count == 1 ? "Gruppe" : "Gruppen") · \(total) Bilder · Klick öffnet Vollansicht (◄ ► navigieren)")
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

    private func resolvedPickIndex(groupIdx: Int, group: [ImageDocument]) -> Int {
        pickOverrides[groupIdx] ?? Self.recommendedPickIndex(in: group)
    }

    // Heuristik für Erstauswahl: RAW bevorzugen, dann größte Datei (oft die beste Aufnahme).
    static func recommendedPickIndex(in group: [ImageDocument]) -> Int {
        if let idx = group.firstIndex(where: { $0.isRAW }) { return idx }
        var bestIdx = 0
        var bestSize: Int = -1
        for (idx, doc) in group.enumerated() {
            let size = (try? doc.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap({ $0 }) ?? 0
            if size > bestSize {
                bestSize = size
                bestIdx = idx
            }
        }
        return bestIdx
    }

    private func trashRest(idx: Int, group: [ImageDocument]) {
        let keep = resolvedPickIndex(groupIdx: idx, group: group)
        let toTrash = group.enumerated().filter { $0.offset != keep }.map { $0.element }
        viewModel.moveToAppTrash(toTrash)
        pickOverrides.removeValue(forKey: idx)
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

// MARK: - Lightbox

private struct SimilarLightbox: View {
    let group: [ImageDocument]
    @Binding var currentIdx: Int
    let pickIdx: Int
    let onPickChange: (Int) -> Void
    let onClose: () -> Void

    @State private var previewImage: NSImage? = nil
    @State private var loadingURL: URL? = nil
    @State private var keyMonitor: Any? = nil

    private var doc: ImageDocument? {
        guard currentIdx >= 0, currentIdx < group.count else { return nil }
        return group[currentIdx]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                imageArea
                controls
            }
            .padding(16)
        }
        .onAppear {
            installKeyMonitor()
            loadCurrent()
        }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: currentIdx) { _ in loadCurrent() }
    }

    private var header: some View {
        HStack {
            if let doc = doc {
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.filename).foregroundColor(.white).font(.headline)
                    Text("\(currentIdx + 1) / \(group.count)  ·  ◄ ► navigieren · ESC schließen")
                        .foregroundColor(.gray).font(.caption)
                }
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder private var imageArea: some View {
        ZStack {
            if let img = previewImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button { prev() } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(currentIdx > 0 ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(currentIdx == 0)

            Spacer()

            Button {
                onPickChange(currentIdx)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pickIdx == currentIdx ? "star.fill" : "star")
                    Text(pickIdx == currentIdx ? "Als Beste markiert" : "Als Beste wählen")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(pickIdx == currentIdx ? Color.green : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button { next() } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(currentIdx < group.count - 1 ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(currentIdx >= group.count - 1)
        }
        .padding(.horizontal, 20)
    }

    private func prev() { if currentIdx > 0 { currentIdx -= 1 } }
    private func next() { if currentIdx < group.count - 1 { currentIdx += 1 } }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: prev(); return nil               // ◄
            case 124: next(); return nil               // ►
            case 53:  onClose(); return nil            // ESC
            case 49:  onPickChange(currentIdx); return nil // Leertaste = Beste markieren
            default:  return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    // Preview-Decode auf Background-Queue mit URL-Guard gegen Race,
    // wenn der Nutzer schneller wechselt als der Decode fertig wird.
    private func loadCurrent() {
        guard let doc = doc else { return }
        let url = doc.url
        loadingURL = url
        previewImage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let img: NSImage?
            do {
                let cg = try RAWImageDecoder.thumbnail(url: url, maxDimension: 1600)
                img = NSImage(cgImage: cg, size: .zero)
            } catch {
                img = nil
            }
            DispatchQueue.main.async {
                if loadingURL == url {
                    previewImage = img
                }
            }
        }
    }
}
