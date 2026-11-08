import SwiftUI
import AppKit

private struct YearGroup: Identifiable {
    let year: String
    let documents: [ImageDocument]
    var id: String { year }
}

struct LibraryFullGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var cellSpacing: CGFloat { 0 }
    private var columns: [GridItem] {
        return [GridItem(.adaptive(minimum: viewModel.gridThumbnailSize), spacing: 0)]
    }
    private var cellWidth: CGFloat { viewModel.gridThumbnailSize }
    @StateObject private var scroller = AppKitScroller()

    private var yearGroups: [YearGroup] {
        viewModel.yearGroups.map { YearGroup(year: $0.year, documents: $0.documents) }
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "."; return f
    }()

    private var statusText: String {
        let docs = viewModel.visibleDocuments
        let vidCount = docs.filter { Self.videoExtensions.contains($0.url.pathExtension.lowercased()) }.count
        let photoCount = docs.count - vidCount
        let fmt = Self.countFormatter
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
                            let pad: CGFloat = cellWidth < 50 ? 0 : 8
                            let useYears = yearGroups.count > 1 || (yearGroups.count == 1 && yearGroups[0].year != "Ohne Datum")
                            VStack(alignment: .leading, spacing: 0) {
                                if useYears {
                                    ForEach(yearGroups) { group in
                                        yearSectionHeader(group.year)
                                            .padding(.horizontal, pad)
                                            .padding(.top, pad > 0 ? pad : 4)
                                        LazyVGrid(columns: columns, spacing: 0) {
                                            ForEach(group.documents, id: \.id) { doc in
                                                thumbnailCell(doc)
                                            }
                                        }
                                        .padding(.horizontal, pad)
                                    }
                                } else {
                                    LazyVGrid(columns: columns, spacing: 0) {
                                        ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                                            thumbnailCell(doc)
                                        }
                                    }
                                    .padding(.horizontal, pad)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ScrollViewGrabber(scroller: scroller))
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
