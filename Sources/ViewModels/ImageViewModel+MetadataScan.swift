import Foundation

// Öffentliche Metadaten-Scan-API — Implementierung lebt in ImageLoadingOrchestrator.
extension ImageViewModel {

    func loadMetadataInBackground(for urls: [URL]) {
        loader.loadMetadataInBackground(for: urls)
    }

    func scanExifForLibrary() {
        loader.scanExifForLibrary()
    }

    func scanQualityForLibrary() {
        loader.scanQualityForLibrary()
    }

    func scanMotifForLibrary() {
        loader.scanMotifForLibrary()
    }
}
