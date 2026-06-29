import AppKit
import Foundation

// MARK: - Version History

extension ImageViewModel {

    func loadVersionsForCurrentImage() {
        guard let url = collection.currentDocument?.url else { savedVersions = []; return }
        let (accessURL, stop) = BookmarkStore.shared.access(url: url)
        savedVersions = VersionStore.shared.loadVersions(for: accessURL)
        stop()
    }

    // MARK: - Save Adjusted Image to File

    func saveAdjustedToFile(label: String, metaEntries: [MetadataEntry]? = nil) {
        guard let doc = collection.currentDocument, !doc.isRAW else { return }
        let image = adjustedImage ?? currentImage
        guard let image = image else { return }

        isSavingToFile = true
        let url = doc.url
        let idx = collection.currentIndex

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let meta = try VersionStore.shared.backupFile(at: accessURL, label: label)
                try VersionStore.shared.writeImage(image, to: accessURL)
                if let entries = metaEntries {
                    try self.metadataService.writePhotoMetadataSync(url: accessURL, entries: entries)
                }
                Log.info("Bild gespeichert: \(url.lastPathComponent)")
                let updatedMeta = self.metadataService.readPhotoMetadata(from: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(meta)
                    self.redoStack.removeAll()
                    self.pendingMetadataEntries = nil
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = image
                        self.collection.documents[idx].thumbnail = nil
                        self.collection.documents[idx].metadata = updatedMeta
                    }
                    self.adjustedImage = nil
                    self.displayImageVersion = UUID()
                    self.loadVersionsForCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Speichern fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Version Revert

    func revertToVersion(_ meta: ImageVersionMeta) {
        guard let doc = collection.currentDocument else { return }
        isSavingToFile = true
        let url = doc.url
        let idx = collection.currentIndex

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(meta, to: accessURL)
                Log.info("Version wiederhergestellt: \(meta.date)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Revert fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Version wiederherstellen fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Undo / Redo Save

    func undoSave() {
        guard !undoStack.isEmpty, let doc = collection.currentDocument else { return }
        let undoMeta = undoStack.removeLast()
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let redoMeta = try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(undoMeta, to: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.redoStack.append(redoMeta)
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Undo fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Undo fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    func redoSave() {
        guard !redoStack.isEmpty, let doc = collection.currentDocument else { return }
        let redoMeta = redoStack.removeLast()
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let undoMeta = try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(redoMeta, to: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(undoMeta)
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Redo fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Redo fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Metadata

    func saveMetadata(_ entries: [MetadataEntry]) {
        guard let doc = collection.currentDocument else { return }
        let index = collection.currentIndex
        isSavingMetadata = true
        Log.info("Speichere Metadaten für \(doc.filename) (\(entries.count) Einträge)")
        metadataService.writePhotoMetadata(url: doc.url, entries: entries) { [weak self] error in
            guard let self = self else { return }
            self.isSavingMetadata = false
            if let error = error {
                Log.error("Metadaten speichern fehlgeschlagen: \(error.localizedDescription)")
                self.errorMessage = "Metadaten speichern fehlgeschlagen: \(error.localizedDescription)"
            } else {
                Log.info("Metadaten erfolgreich gespeichert")
                let updated = self.metadataService.readPhotoMetadata(from: doc.url)
                guard index < self.collection.documents.count,
                      self.collection.documents[index].url == doc.url else { return }
                self.collection.documents[index].metadata = updated
            }
        }
    }

    func saveMetadata() {
        guard hasMetadataChanges, let entries = pendingMetadataEntries else { return }
        saveOnlyMeta(entries: entries, label: "Metadaten")
    }

    func saveOnlyMeta(entries: [MetadataEntry], label: String) {
        guard let doc = collection.currentDocument else { return }
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let meta = try VersionStore.shared.backupFile(at: accessURL, label: label)
                try self.metadataService.writePhotoMetadataSync(url: accessURL, entries: entries)
                let updatedMeta = self.metadataService.readPhotoMetadata(from: accessURL)
                Log.info("Metadaten gespeichert: \(url.lastPathComponent)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(meta)
                    self.redoStack.removeAll()
                    self.pendingMetadataEntries = nil
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].metadata = updatedMeta
                    }
                    self.loadVersionsForCurrentImage()
                }
            } catch {
                Log.error("Metadaten speichern fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Metadaten speichern fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }
}
