import Foundation
import Combine

class ImageCollection: ObservableObject {
    @Published var documents: [ImageDocument] = []
    @Published var currentIndex: Int = 0
    @Published var selectedIndices: Set<Int> = []

    var currentDocument: ImageDocument? {
        guard !documents.isEmpty, currentIndex < documents.count else { return nil }
        return documents[currentIndex]
    }

    var hasNext: Bool { currentIndex < documents.count - 1 }
    var hasPrevious: Bool { currentIndex > 0 }

    func setDocuments(_ docs: [ImageDocument], selectingURL url: URL? = nil) {
        documents = docs.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        if let url = url, let idx = documents.firstIndex(where: { $0.url == url }) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
        selectedIndices = [currentIndex]
    }

    func select(index: Int) {
        guard index >= 0 && index < documents.count else { return }
        currentIndex = index
        selectedIndices = [index]
    }

    func next() {
        if hasNext { currentIndex += 1; selectedIndices = [currentIndex] }
    }

    func previous() {
        if hasPrevious { currentIndex -= 1; selectedIndices = [currentIndex] }
    }

    func update(document: ImageDocument, at index: Int) {
        guard index < documents.count else { return }
        documents[index] = document
    }

    func appendDocuments(_ newDocs: [ImageDocument]) {
        documents.append(contentsOf: newDocs)
    }
}
