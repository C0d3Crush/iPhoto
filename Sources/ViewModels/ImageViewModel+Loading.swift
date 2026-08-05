import Foundation

// Öffentliche Lade-API — Implementierung lebt in ImageLoadingOrchestrator.
// Diese Wrapper existieren nur, damit die 14 Aufrufer-Dateien unverändert bleiben.
extension ImageViewModel {

    func loadCurrentImage() {
        loader.loadCurrentImage()
    }

    func loadFullRes(url: URL, token: UUID) {
        loader.loadFullRes(url: url, token: token)
    }

    func upgradeToFullResIfNeeded() {
        loader.upgradeToFullResIfNeeded()
    }

    func prefetchAdjacent() {
        loader.prefetchAdjacent()
    }
}
