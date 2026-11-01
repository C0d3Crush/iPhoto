import SwiftUI
import AppKit

// MARK: - Column definition

enum ListColumn: String, CaseIterable, Hashable {
    case name, date, size, type, rating, flag

    var displayName: String {
        switch self {
        case .name:   return "Name"
        case .date:   return "Datum"
        case .size:   return "Größe"
        case .type:   return "Art"
        case .rating: return "Bewertung"
        case .flag:   return "Markierung"
        }
    }

    var fixedWidth: CGFloat? {
        switch self {
        case .name:   return nil      // flexible — fills remaining width
        case .date:   return 168
        case .size:   return 74
        case .type:   return 56
        case .rating: return 74
        case .flag:   return 80
        }
    }

    var isAlwaysVisible: Bool { self == .name }

    // Maps to a global SortCriterion pair (asc, desc). nil = not sortable.
    var sortPair: (asc: SortCriterion, desc: SortCriterion)? {
        switch self {
        case .name:   return (.filenameAsc, .filenameDesc)
        case .date:   return (.dateAsc, .dateDesc)
        case .rating: return (.ratingDesc, .ratingDesc)
        default:      return nil
        }
    }

    static func loadVisible() -> Set<ListColumn> {
        guard let raw = UserDefaults.standard.string(forKey: "listView.visibleColumns") else {
            return Set(ListColumn.allCases)
        }
        let decoded = Set(raw.split(separator: ",").compactMap { ListColumn(rawValue: String($0)) })
        return decoded.isEmpty ? Set(ListColumn.allCases) : decoded.union([.name])
    }

    static func saveVisible(_ cols: Set<ListColumn>) {
        UserDefaults.standard.set(cols.map(\.rawValue).joined(separator: ","),
                                  forKey: "listView.visibleColumns")
    }
}

// MARK: - Main view

struct LibraryListView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var visibleColumns: Set<ListColumn> = ListColumn.loadVisible()

    private var orderedVisible: [ListColumn] {
        ListColumn.allCases.filter { visibleColumns.contains($0) }
    }

    private var isAlbumContext: Bool {
        switch viewModel.navSelection {
        case .album, .smartFolder, .albumFolder: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            if viewModel.collection.documents.isEmpty {
                Color(NSColor.windowBackgroundColor).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64)).foregroundColor(.secondary)
                    Text("Bilder hier ablegen").font(.title2).foregroundColor(.secondary)
                    Text("oder ⌘O zum Öffnen").foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            } else {
                VStack(spacing: 0) {
                    ListHeader(columns: orderedVisible,
                               visibleColumns: $visibleColumns,
                               sortCriterion: $viewModel.sortCriterion)
                    Divider()
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            if isAlbumContext {
                                AlbumBannerView()
                                    .environmentObject(viewModel)
                                Divider()
                            }
                            ForEach(Array(viewModel.visibleDocuments.enumerated()), id: \.element.id) { rowIdx, doc in
                                let idx = viewModel.collectionIndex(for: doc) ?? 0
                                let sel = viewModel.collection.selectedIndices.contains(idx)
                                ListRow(doc: doc, isSelected: sel, rowIndex: rowIdx, columns: orderedVisible)
                                    .onTapGesture { viewModel.selectDocument(at: idx) }
                                    .contextMenu {
                                        ThumbnailContextMenu(doc: doc).environmentObject(viewModel)
                                    }
                                    .onAppear { viewModel.requestVisibleThumbnail(at: idx) }
                            }
                        }
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }

            DropTargetView().environmentObject(viewModel)
        }
        .onChange(of: visibleColumns) { ListColumn.saveVisible($0) }
    }
}

// MARK: - Column header

private struct ListHeader: View {
    let columns: [ListColumn]
    @Binding var visibleColumns: Set<ListColumn>
    @Binding var sortCriterion: SortCriterion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { col in
                headerCell(col)
                if col != columns.last {
                    Divider().frame(height: 18)
                }
            }
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
        .contextMenu { columnToggleMenu }
    }

    @ViewBuilder
    private func headerCell(_ col: ListColumn) -> some View {
        let isSorted = isSortedBy(col)
        let isAsc    = isAscending(col)

        Button(action: { toggleSort(col) }) {
            HStack(spacing: 4) {
                Text(col.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSorted ? .primary : .secondary)
                    .lineLimit(1)
                if isSorted {
                    Image(systemName: isAsc ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: col.fixedWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(col.sortPair == nil)
        .frame(maxWidth: col.fixedWidth == nil ? .infinity : col.fixedWidth)
    }

    @ViewBuilder
    private var columnToggleMenu: some View {
        ForEach(ListColumn.allCases.filter { !$0.isAlwaysVisible }, id: \.self) { col in
            Button(action: { toggleColumn(col) }) {
                if visibleColumns.contains(col) {
                    Label(col.displayName, systemImage: "checkmark")
                } else {
                    Text(col.displayName)
                }
            }
        }
    }

    private func toggleColumn(_ col: ListColumn) {
        if visibleColumns.contains(col) {
            visibleColumns.remove(col)
        } else {
            visibleColumns.insert(col)
        }
    }

    private func isSortedBy(_ col: ListColumn) -> Bool {
        guard let pair = col.sortPair else { return false }
        return sortCriterion == pair.asc || sortCriterion == pair.desc
    }

    private func isAscending(_ col: ListColumn) -> Bool {
        guard let pair = col.sortPair else { return true }
        return sortCriterion == pair.asc
    }

    private func toggleSort(_ col: ListColumn) {
        guard let pair = col.sortPair else { return }
        if sortCriterion == pair.asc {
            sortCriterion = pair.desc
        } else {
            sortCriterion = pair.asc
        }
    }
}

// MARK: - Row

private struct ListRow: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let doc: ImageDocument
    let isSelected: Bool
    let rowIndex: Int
    let columns: [ListColumn]

    @State private var fileSize: String = ""
    @State private var fileDate: Date? = nil

    // Badge visibility — mirrors ThumbnailCell AppStorage keys
    @AppStorage("badge.rating")      private var showRating      = true
    @AppStorage("badge.colorLabel")  private var showColorLabel  = true
    @AppStorage("badge.flag")        private var showFlag        = true
    @AppStorage("badge.blurry")      private var showBlurry      = true
    @AppStorage("badge.under")       private var showUnder       = true
    @AppStorage("badge.over")        private var showOver        = true
    @AppStorage("badge.eyes")        private var showEyes        = true
    @AppStorage("badge.bestInStack") private var showBestInStack = true
    @AppStorage("badge.adjustments") private var showAdjustments = true
    @AppStorage("badge.hdr")         private var showHDR         = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { col in
                cell(for: col)
                if col != columns.last {
                    Divider().frame(height: 20).opacity(0)  // invisible spacer to align widths
                }
            }
        }
        .frame(height: 32)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onAppear { loadFileAttributes() }
    }

    @ViewBuilder
    private func cell(for col: ListColumn) -> some View {
        switch col {
        case .name:
            HStack(spacing: 8) {
                thumbnail
                Text(doc.url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

        case .date:
            Text(dateString)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(width: col.fixedWidth, alignment: .leading)

        case .size:
            Text(fileSize)
                .font(.system(size: 12).monospacedDigit())
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .frame(width: col.fixedWidth, alignment: .trailing)

        case .type:
            Text(doc.url.pathExtension.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .frame(width: col.fixedWidth, alignment: .leading)

        case .rating:
            HStack(spacing: 1) {
                if doc.rating > 0 {
                    Text(String(repeating: "★", count: doc.rating))
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: col.fixedWidth)

        case .flag:
            HStack(spacing: 3) {
                if showFlag { flagIcon }
                if showColorLabel && doc.colorLabel != .none {
                    Circle()
                        .fill(Color(doc.colorLabel.displayColor))
                        .frame(width: 7, height: 7)
                }
                let q = viewModel.qualityFlags(for: doc)
                let isHDR = doc.metadata.first(where: { $0.key == "exif.HDR" })?.value == "Ja"
                if showBestInStack && viewModel.bestInStackIDs.contains(doc.id) {
                    listBadge("crown.fill", .yellow)
                }
                if showBlurry     && q.blur  { listBadge("drop.triangle.fill", .purple) }
                if showUnder      && q.under  { listBadge("moon.fill",          .blue)   }
                if showOver       && q.over   { listBadge("sun.max.fill",       .yellow) }
                if showEyes       && q.eyes   { listBadge("eye.slash.fill",     .pink)   }
                if showAdjustments && doc.hasPersistedAdjustments { listBadge("wand.and.stars", .accentColor) }
                if showHDR        && isHDR    { listBadge("sparkles",           Color(NSColor.systemTeal)) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: col.fixedWidth)
        }
    }

    private var thumbnail: some View {
        Group {
            if let thumb = doc.thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(NSColor.controlBackgroundColor)
                    .overlay(Image(systemName: "photo").font(.system(size: 10)).foregroundColor(.secondary))
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    @ViewBuilder
    private var flagIcon: some View {
        switch doc.flagStatus {
        case .pick:
            Image(systemName: "flag.fill").font(.system(size: 10)).foregroundColor(.orange)
        case .reject:
            Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(.red)
        case .none:
            EmptyView()
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        return rowIndex % 2 == 0
            ? Color(NSColor.windowBackgroundColor)
            : Color(NSColor.controlBackgroundColor)
    }

    private func listBadge(_ system: String, _ color: Color) -> some View {
        Image(systemName: system)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
    }

    private var dateString: String {
        guard let date = fileDate else { return "–" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    private func loadFileAttributes() {
        let url = doc.url
        DispatchQueue.global(qos: .utility).async {
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let sz = vals?.fileSize
            let dt = vals?.contentModificationDate
            let szStr: String
            if let bytes = sz {
                if bytes >= 1_000_000 {
                    szStr = String(format: "%.1f MB", Double(bytes) / 1_000_000)
                } else if bytes >= 1_000 {
                    szStr = String(format: "%.0f KB", Double(bytes) / 1_000)
                } else {
                    szStr = "\(bytes) B"
                }
            } else {
                szStr = "–"
            }
            DispatchQueue.main.async {
                self.fileSize = szStr
                self.fileDate = dt
            }
        }
    }
}
