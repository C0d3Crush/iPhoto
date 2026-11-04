import SwiftUI
import AppKit

private struct YearGroup: Identifiable {
    let year: String
    let documents: [ImageDocument]
    var id: String { year }
}

struct LibraryFullGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var cellSpacing: CGFloat { viewModel.gridThumbnailSize < 50 ? 1 : (viewModel.gridThumbnailSize < 100 ? 4 : 8) }
    private var columns: [GridItem] {
        let sp = cellSpacing
        return [GridItem(.adaptive(minimum: viewModel.gridThumbnailSize + sp))]
    }
    private var cellWidth: CGFloat { viewModel.gridThumbnailSize }
    @StateObject private var scroller = AppKitScroller()

    private var yearGroups: [YearGroup] {
        var grouped: [String: [ImageDocument]] = [:]
        for doc in viewModel.visibleDocuments {
            let year: String
            if let val = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value,
               val.count >= 4, let y = Int(val.prefix(4)), y > 1800 {
                year = String(y)
            } else {
                year = "Ohne Datum"
            }
            grouped[year, default: []].append(doc)
        }
        let sorted = grouped.keys.sorted { a, b in
            if a == "Ohne Datum" { return false }
            if b == "Ohne Datum" { return true }
            return a > b
        }
        return sorted.map { YearGroup(year: $0, documents: grouped[$0]!) }
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    private var statusText: String {
        let docs = viewModel.visibleDocuments
        let vidCount = docs.filter { Self.videoExtensions.contains($0.url.pathExtension.lowercased()) }.count
        let photoCount = docs.count - vidCount
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        let ps = fmt.string(from: NSNumber(value: photoCount)) ?? "\(photoCount)"
        let vs = fmt.string(from: NSNumber(value: vidCount)) ?? "\(vidCount)"
        return vidCount > 0 ? "\(ps) Fotos, \(vs) Videos · Gerade aktualisiert" : "\(ps) Fotos · Gerade aktualisiert"
    }

    private var isAlbumContext: Bool {
        switch viewModel.navSelection {
        case .album, .smartFolder, .albumFolder: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
          Group {
            if viewModel.collection.documents.isEmpty {
                ZStack {
                    Color(NSColor.windowBackgroundColor).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Bilder hier ablegen")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("oder ⌘O zum Öffnen")
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                }
            } else {
                VStack(spacing: 0) {
                    if isAlbumContext {
                        AlbumBannerView()
                            .environmentObject(viewModel)
                        Divider()
                    }
                    VStack(spacing: 0) {
                        ScrollView {
                            if case .eloRange(let lo, let hi) = viewModel.navSelection {
                                eloRangeBanner(lo: lo, hi: hi)
                            }
                            let sp = cellSpacing
                            let useYears = yearGroups.count > 1 || (yearGroups.count == 1 && yearGroups[0].year != "Ohne Datum")
                            if useYears {
                                LazyVGrid(columns: columns, spacing: sp, pinnedViews: [.sectionHeaders]) {
                                    ForEach(yearGroups) { group in
                                        Section(header: yearSectionHeader(group.year)) {
                                            ForEach(group.documents, id: \.id) { doc in
                                                thumbnailCell(doc)
                                            }
                                        }
                                    }
                                }
                                .padding(cellWidth < 50 ? 4 : 12)
                                .frame(maxWidth: .infinity)
                                .background(ScrollViewGrabber(scroller: scroller))
                            } else {
                                LazyVGrid(columns: columns, spacing: sp) {
                                    ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                                        thumbnailCell(doc)
                                    }
                                }
                                .padding(cellWidth < 50 ? 4 : 12)
                                .frame(maxWidth: .infinity)
                                .background(ScrollViewGrabber(scroller: scroller))
                            }
                        }
                        .background(Color(NSColor.windowBackgroundColor))
                        .onChange(of: viewModel.collection.currentIndex) { _ in
                            scrollToCurrent()
                        }

                        Divider()
                        HStack {
                            Spacer()
                            Text(statusText)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }
            }
          }
          DropTargetView()
              .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private func thumbnailCell(_ doc: ImageDocument) -> some View {
        let idx = viewModel.collectionIndex(for: doc) ?? 0
        let isSel = viewModel.collection.selectedIndices.contains(idx)
        let q = viewModel.qualityFlags(for: doc)
        ThumbnailCell(document: doc, isSelected: isSel, thumbnailWidth: cellWidth,
                      stackCount: viewModel.stackCounts[doc.id] ?? 0,
                      isStackExpanded: viewModel.isStackExpanded(doc),
                      isStackMember: viewModel.stackLeaderByMember[doc.id].map { $0 != doc.id } ?? false,
                      onStackToggle: { viewModel.toggleStack(leader: doc) },
                      isBlurry: q.blur, isUnder: q.under, isOver: q.over,
                      isEyesClosed: q.eyes,
                      isBestInStack: viewModel.bestInStackIDs.contains(doc.id))
            .frame(width: cellWidth + cellSpacing)
            .contentShape(Rectangle())
            .onAppear { viewModel.requestVisibleThumbnail(at: idx) }
            .onTapGesture(count: 2) { openDetail(at: idx) }
            .onTapGesture { handleTap(at: idx) }
            .contextMenu { ThumbnailContextMenu(doc: doc).environmentObject(viewModel) }
            .onDrag { NSItemProvider(object: doc.url as NSURL) }
    }

    private func yearSectionHeader(_ year: String) -> some View {
        HStack {
            Text(year)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }

    // Kein ScrollViewProxy.scrollTo: hinterlässt auf macOS 11 ein persistentes
    // Scroll-Ziel, das nach Layout-Neuaufbau crasht (Bug #31) — AppKit-Scroll.
    private func scrollToCurrent() {
        guard let cur = viewModel.collection.currentDocument,
              let pos = viewModel.visiblePosition(for: cur.id) else { return }
        let count = viewModel.visibleDocuments.count
        let clipWidth = scroller.scrollView?.contentView.bounds.width ?? 0
        let itemWidth = cellWidth + cellSpacing
        let colSpacing = cellSpacing
        let cols = max(1, Int((clipWidth - 24 + colSpacing) / (itemWidth + colSpacing)))
        viewModel.gridColumnCount = cols
        scroller.centerRow(position: pos, count: count, columns: cols, verticalPadding: 12)
    }

    private func eloRangeBanner(lo: Double, hi: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.accentColor)
            Text("ELO \(Int(lo.rounded())) – \(Int(hi.rounded()))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text("· \(viewModel.visibleDocuments.count) Bilder")
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { viewModel.navSelection = .library }) {
                Label("Alle Bilder", systemImage: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Filterung aufheben")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func openDetail(at index: Int) {
        viewModel.selectDocument(at: index)
        let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
        if isLibrary {
            viewModel.showingLibraryDetail = true
        } else {
            viewModel.showFullGrid = false
        }
    }

    private func handleTap(at index: Int) {
        let flags = viewModel.lastClickModifiers
        if flags.contains(.command) {
            viewModel.toggleSelection(at: index)
        } else if flags.contains(.shift) {
            viewModel.extendSelection(to: index)
        } else {
            viewModel.selectDocument(at: index)
        }
    }

}
