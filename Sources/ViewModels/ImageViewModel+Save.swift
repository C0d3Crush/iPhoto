import AppKit
import Foundation

// MARK: - Version History

extension ImageViewModel {

    func loadVersionsForCurrentImage() {
        guard let url = collection.currentDocument?.url else { versions.savedVersions = []; return }
        // Clear per-file undo/redo stacks when the active document changes.
        if url != versionHistoryURL {
            versions.undoStack = []
            versions.redoStack = []
            versionHistoryURL = url
        }
        // Bookmark-Resolve + Verzeichnis-Anlage + JSON-Read gehören nicht auf den Main-Thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            let versions = VersionStore.shared.loadVersions(for: accessURL)
            stop()
            DispatchQueue.main.async {
                guard let self = self, self.collection.currentDocument?.url == url else { return }
                self.versions.savedVersions = versions
            }
        }
    }

    // Gemeinsames Gerüst aller Datei-Schreiboperationen: BG-Queue, Security-Scoped-Access,
    // isSavingToFile-Handling; Fehler landen in Log und errorMessage (UI).
    // `work` läuft auf dem BG-Thread und liefert die Main-Thread-Fortsetzung für den Erfolgsfall.
    private func performFileOperation(on url: URL, errorLabel: String,
                                      work: @escaping (URL) throws -> (() -> Void)) {
        versions.isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let applyOnMain = try work(accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.versions.isSavingToFile = false
                    applyOnMain()
                }
            } catch {
                Log.error("\(errorLabel) fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.versions.isSavingToFile = false
                    self?.errorMessage = "\(errorLabel) fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    // Nach Wiederherstellen einer Datei-Version: Bitmaps des betroffenen Dokuments verwerfen
    // und, wenn es noch das aktive Bild ist, Anpassungen + Versionshistorie neu laden.
    private func refreshAfterFileRestore(url: URL) {
        guard let idx = collection.documentIndexByURL[url] else { return }
        var doc = collection.documents[idx]
        doc.cgImage = nil
        doc.thumbnail = nil
        collection.documents[idx] = doc
        if collection.currentDocument?.url == url {
            resetAdjustments()
            loadVersionsForCurrentImage()
            loadCurrentImage()
        }
    }

    // MARK: - Version Revert

    func revertToVersion(_ meta: ImageVersionMeta) {
        guard let doc = collection.currentDocument else { return }
        let url = doc.url

        performFileOperation(on: url, errorLabel: "Version wiederherstellen") { [weak self] accessURL in
            try VersionStore.shared.backupFile(at: accessURL)
            try VersionStore.shared.restoreVersion(meta, to: accessURL)
            CatalogStore.shared.invalidateExifCache(path: accessURL.path)
            let updatedMeta = self?.metadataService.readPhotoMetadata(from: accessURL) ?? []
            Log.info("Version wiederhergestellt: \(meta.date)")
            return { [weak self] in
                guard let self = self, let idx = self.collection.documentIndexByURL[url] else { return }
                self.collection.documents[idx].metadata = updatedMeta
                self.refreshAfterFileRestore(url: url)
            }
        }
    }

    // MARK: - Undo / Redo Save

    func undoSave() { restoreFromHistory(isUndo: true) }
    func redoSave() { restoreFromHistory(isUndo: false) }

    private func restoreFromHistory(isUndo: Bool) {
        guard let doc = collection.currentDocument else { return }
        let meta: ImageVersionMeta
        if isUndo {
            guard !versions.undoStack.isEmpty else { return }
            meta = versions.undoStack.removeLast()
        } else {
            guard !versions.redoStack.isEmpty else { return }
            meta = versions.redoStack.removeLast()
        }
        // Guard: verify the meta belongs to the current document before writing.
        guard FileManager.default.fileExists(atPath: VersionStore.shared.versionURL(meta, for: doc.url).path) else {
            Log.error("Undo/Redo: Version nicht in Versionsordner von \(doc.url.lastPathComponent) — Eintrag verworfen")
            return
        }
        let url = doc.url

        performFileOperation(on: url, errorLabel: isUndo ? "Undo" : "Redo") { [weak self] accessURL in
            // Aktuellen Stand sichern, damit die Operation umkehrbar bleibt
            let counterpart = try VersionStore.shared.backupFile(at: accessURL)
            try VersionStore.shared.restoreVersion(meta, to: accessURL)
            CatalogStore.shared.invalidateExifCache(path: accessURL.path)
            let updatedMeta = self?.metadataService.readPhotoMetadata(from: accessURL) ?? []
            return { [weak self] in
                guard let self = self else { return }
                if isUndo {
                    self.versions.redoStack.append(counterpart)
                } else {
                    self.versions.undoStack.append(counterpart)
                }
                if let idx = self.collection.documentIndexByURL[url] {
                    self.collection.documents[idx].metadata = updatedMeta
                }
                self.refreshAfterFileRestore(url: url)
            }
        }
    }

    // MARK: - Metadata

    func saveMetadata() {
        guard hasMetadataChanges, let entries = versions.pendingMetadataEntries else { return }
        saveOnlyMeta(entries: entries, label: "Metadaten")
    }

    func saveOnlyMeta(entries: [MetadataEntry], label: String) {
        guard let doc = collection.currentDocument else { return }
        let url = doc.url

        performFileOperation(on: url, errorLabel: "Metadaten speichern") { [weak self] accessURL in
            guard let self = self else { return {} }
            let meta = try VersionStore.shared.backupFile(at: accessURL, label: label)
            try self.metadataService.writePhotoMetadataSync(url: accessURL, entries: entries)
            CatalogStore.shared.invalidateExifCache(path: accessURL.path)
            let updatedMeta = self.metadataService.readPhotoMetadata(from: accessURL)
            Log.info("Metadaten gespeichert: \(url.lastPathComponent)")
            return { [weak self] in
                guard let self = self else { return }
                self.versions.undoStack.append(meta)
                self.versions.redoStack.removeAll()
                self.versions.pendingMetadataEntries = nil
                if let idx = self.collection.documentIndexByURL[url] {
                    self.collection.documents[idx].metadata = updatedMeta
                }
                self.loadVersionsForCurrentImage()
            }
        }
    }
}
