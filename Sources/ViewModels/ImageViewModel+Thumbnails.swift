import Foundation

// Öffentliche Thumbnail-API — Implementierung lebt in ImageLoadingOrchestrator.
extension ImageViewModel {

    func loadThumbnails() {
        loader.loadThumbnails()
    }

    func requestVisibleThumbnail(at index: Int) {
        loader.requestVisibleThumbnail(at: index)
    }
}
