import SwiftUI

private struct ModeTile {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct ModeSwitcherView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private func makeTiles() -> [ModeTile] {
        var tiles: [ModeTile] = [
            ModeTile(
                title: "Bibliothek",
                subtitle: "\(viewModel.collection.documents.filter { !$0.isTrashed }.count) Bilder",
                icon: "photo.stack",
                color: Color(red: 0.2, green: 0.45, blue: 0.85)
            ) {
                viewModel.navSelection = .library
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
        ]

        if viewModel.compareFeatureEnabled {
            tiles.append(ModeTile(
                title: "Bildvergleich",
                subtitle: "ELO-Duelle starten",
                icon: "arrow.left.arrow.right",
                color: Color(red: 0.5, green: 0.2, blue: 0.75)
            ) {
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
                viewModel.startCompareMode()
            })
        }

        tiles += [
            ModeTile(
                title: "Duplikate",
                subtitle: viewModel.quality.duplicateGroups.isEmpty
                    ? "Keine gefunden"
                    : "\(viewModel.quality.duplicateGroups.count) Gruppen",
                icon: "doc.on.doc",
                color: Color(red: 0.85, green: 0.4, blue: 0.1)
            ) {
                viewModel.navSelection = .duplicates
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Ähnliche Bilder",
                subtitle: viewModel.quality.similarGroups.isEmpty
                    ? "Keine gefunden"
                    : "\(viewModel.quality.similarGroups.count) Gruppen",
                icon: "square.on.square.dashed",
                color: Color(red: 0.1, green: 0.55, blue: 0.75)
            ) {
                viewModel.navSelection = .similar
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Unscharf",
                subtitle: "\(viewModel.quality.blurryDocuments.count) Bilder",
                icon: "drop.triangle",
                color: Color(red: 0.4, green: 0.2, blue: 0.65)
            ) {
                viewModel.navSelection = .blurry
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Unterbelichtet",
                subtitle: "\(viewModel.quality.underexposedDocuments.count) Bilder",
                icon: "moon.fill",
                color: Color(red: 0.25, green: 0.15, blue: 0.45)
            ) {
                viewModel.navSelection = .underexposed
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Überbelichtet",
                subtitle: "\(viewModel.quality.overexposedDocuments.count) Bilder",
                icon: "sun.max.fill",
                color: Color(red: 0.8, green: 0.65, blue: 0.05)
            ) {
                viewModel.navSelection = .overexposed
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Augen zu",
                subtitle: "\(viewModel.quality.closedEyeDocuments.count) Bilder",
                icon: "eye.slash.fill",
                color: Color(red: 0.75, green: 0.2, blue: 0.45)
            ) {
                viewModel.navSelection = .closedEyes
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
            ModeTile(
                title: "Papierkorb",
                subtitle: viewModel.trashedCount == 0 ? "Leer" : "\(viewModel.trashedCount) Bilder",
                icon: viewModel.trashedCount > 0 ? "trash.fill" : "trash",
                color: Color(red: 0.65, green: 0.1, blue: 0.1)
            ) {
                viewModel.navSelection = .trash
                withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
            },
        ]
        return tiles
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 2)]

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
                }

            VStack(spacing: 0) {
                HStack {
                    Text("Ansicht wählen")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) { viewModel.showModeSwitcher = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        let tiles = makeTiles()
                        ForEach(tiles.indices, id: \.self) { i in
                            TileButton(tile: tiles[i])
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

private struct TileButton: View {
    let tile: ModeTile
    @State private var isHovered = false

    var body: some View {
        Button(action: tile.action) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Image(systemName: tile.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 14)
                    .padding(.bottom, 8)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(tile.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                tile.color
                    .brightness(isHovered ? 0.12 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}
