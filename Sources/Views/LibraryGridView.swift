import SwiftUI

struct LibraryGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private let columns = [GridItem(.adaptive(minimum: 116, maximum: 116), spacing: 12)]

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
                            ThumbnailCell(document: doc, isSelected: index == viewModel.collection.currentIndex)
                                .id(index)
                                .frame(width: 116)
                                .contentShape(Rectangle())
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
