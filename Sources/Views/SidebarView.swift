import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(viewModel.collection.documents.enumerated()), id: \.element.id) { index, doc in
                        ThumbnailCell(document: doc, isSelected: index == viewModel.collection.currentIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.selectDocument(at: index) }
                    }
                }
                .padding(8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
