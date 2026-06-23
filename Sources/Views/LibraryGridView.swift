import SwiftUI

struct LibraryGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 12)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.collection.documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Keine Bilder importiert")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(viewModel.collection.documents.enumerated()), id: \.element.id) { index, doc in
                            LibraryCell(document: doc, isSelected: index == viewModel.collection.currentIndex)
                                .id(index)
                                .onTapGesture { viewModel.selectDocument(at: index) }
                        }
                    }
                    .padding(8)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
    }
}

private struct LibraryCell: View {
    let document: ImageDocument
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .aspectRatio(4/3, contentMode: .fit)

                if let thumb = document.thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(4/3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            Text(document.filename)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }
}
