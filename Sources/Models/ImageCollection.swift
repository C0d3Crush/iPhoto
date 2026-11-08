import Foundation
import Combine

/// Invariante: Alle Lese- und Schreibzugriffe erfolgen auf dem Main-Thread.
/// Background-Tasks müssen Wert-Kopien (URL, Index) capturen und Ergebnisse via
/// DispatchQueue.main.async zurückschreiben. Verletzungen führten früher zu
/// CoW-Data-Races mit Speicherkorruption (Bugs #7, #8, #13, #28, #29) — die
/// didSet-Preconditions lassen solche Fehler jetzt sofort und eindeutig crashen.
class ImageCollection: ObservableObject {
    @Published var documents: [ImageDocument] = [] {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            documentsRevision &+= 1
            var idx = documentIndexByID
            idx.removeAll(keepingCapacity: true)
            for (i, doc) in documents.enumerated() { idx[doc.id] = i }
            documentIndexByID = idx
        }
    }
    /// Zählt jede Mutation von documents — erlaubt Cache-Konsumenten (visibleDocuments)
    /// zu erkennen, ob aufgelöste Dokument-Kopien noch aktuell sind.
    private(set) var documentsRevision: UInt64 = 0
    /// O(1)-Nachschlag: UUID → Index in documents. Immer synchron mit documents.
    private(set) var documentIndexByID: [UUID: Int] = [:]
    @Published var currentIndex: Int = 0 {
        didSet { dispatchPrecondition(condition: .onQueue(.main)) }
    }
    @Published var selectedIndices: Set<Int> = [] {
        didSet { dispatchPrecondition(condition: .onQueue(.main)) }
    }

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
