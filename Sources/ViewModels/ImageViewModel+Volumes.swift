import AppKit
import Foundation

// MARK: - Removable Volumes

extension ImageViewModel {

    func scanForRemovableVolumes() {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.volumeIsRemovableKey, .volumeNameKey],
            options: .skipsHiddenFiles
        ) else { return }
        for url in entries {
            addDetectedVolumeIfRemovable(url)
        }
    }

    @discardableResult
    func addDetectedVolumeIfRemovable(_ url: URL) -> DetectedVolume? {
        let vals = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeNameKey])
        guard vals?.volumeIsRemovable == true else { return nil }
        let name = vals?.volumeName ?? url.lastPathComponent
        let standardPath = url.standardized.path
        if let existing = library.detectedVolumes.first(where: { $0.url.standardized.path == standardPath }) {
            return existing
        }
        let volume = DetectedVolume(id: UUID(), name: name, url: url)
        library.detectedVolumes.append(volume)
        return volume
    }

    func removeDetectedVolume(at url: URL) {
        let path = url.standardized.path
        guard let idx = library.detectedVolumes.firstIndex(where: { $0.url.standardized.path == path }) else { return }
        let volumeID = library.detectedVolumes[idx].id
        library.detectedVolumes.remove(at: idx)
        collection.documents.removeAll { $0.url.standardized.path.hasPrefix(path) }
        if case .volume(let id) = navSelection, id == volumeID {
            navSelection = .library
        }
    }

    func syncVolume(_ volume: DetectedVolume) {
        let volumeID = volume.id
        let volumeName = volume.name
        let volumeURL = volume.url
        enqueueLoading(id: volumeID, label: "Lade \"\(volumeName)\"", icon: "sdcard", done: 0, total: 0)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let found = self.imageFiles(on: volumeURL)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.importFiles(found, selectFirst: false)
                self.dequeueLoading(id: volumeID)
            }
        }
    }

    // Beim Einstecken einer Karte: Bilddateien zählen und Sync-Optionen anbieten.
    func offerVolumeSync(_ volume: DetectedVolume) {
        let volumeURL = volume.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let count = self.imageFiles(on: volumeURL).count
            guard count > 0 else { return }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Speicherkarte \"\(volume.name)\" erkannt"
                alert.informativeText = "\(count) Bilddateien gefunden. Neue Bilder werden in die iPhoto-Bibliothek kopiert. „Speicher freimachen“ löscht anschließend alle Bilder von der Karte, die verifiziert in der Bibliothek liegen."
                alert.addButton(withTitle: "Synchronisieren")
                alert.addButton(withTitle: "Synchronisieren und Speicher freimachen")
                alert.addButton(withTitle: "Abbrechen")
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    self.syncVolumeToLibrary(volume, freeUpSpace: false)
                case .alertSecondButtonReturn:
                    self.syncVolumeToLibrary(volume, freeUpSpace: true)
                default:
                    break
                }
            }
        }
    }

    // Kopiert neue Bilder der Karte in die iPhoto-Bibliothek (~/Pictures/iPhoto).
    // freeUpSpace: löscht danach nur Dateien, deren Name verifiziert im Ziel liegt —
    // fehlgeschlagene Kopien bleiben auf der Karte erhalten.
    func syncVolumeToLibrary(_ volume: DetectedVolume, freeUpSpace: Bool) {
        let volumeID = volume.id
        let volumeName = volume.name
        let volumeURL = volume.url
        let destURL = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        enqueueLoading(id: volumeID, label: "Synchronisiere \"\(volumeName)\"",
                       icon: "arrow.down.circle", done: 0, total: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let sourceFiles = self.imageFiles(on: volumeURL)
            try? fm.createDirectory(at: destURL, withIntermediateDirectories: true)
            let existingNames = Set((try? fm.contentsOfDirectory(atPath: destURL.path).map { $0.lowercased() }) ?? [])
            let newFiles = sourceFiles.filter { !existingNames.contains($0.lastPathComponent.lowercased()) }
            DispatchQueue.main.async { self.updateLoading(id: volumeID, done: 0, total: newFiles.count) }

            var newURLs: [URL] = []
            var failedCount = 0
            var done = 0
            for file in newFiles {
                let dest = destURL.appendingPathComponent(file.lastPathComponent)
                if (try? fm.copyItem(at: file, to: dest)) != nil {
                    newURLs.append(dest)
                } else {
                    failedCount += 1
                }
                done += 1
                let d = done
                DispatchQueue.main.async { self.updateLoading(id: volumeID, done: d, total: newFiles.count) }
            }

            var freedCount = 0
            var keptCount = 0
            if freeUpSpace {
                let destNames = Set((try? fm.contentsOfDirectory(atPath: destURL.path).map { $0.lowercased() }) ?? [])
                for file in sourceFiles {
                    if destNames.contains(file.lastPathComponent.lowercased()),
                       (try? fm.removeItem(at: file)) != nil {
                        freedCount += 1
                    } else {
                        keptCount += 1
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.dequeueLoading(id: volumeID)
                if freeUpSpace {
                    let prefix = volumeURL.standardized.path
                    self.collection.documents.removeAll { $0.url.standardized.path.hasPrefix(prefix) }
                }
                if !newURLs.isEmpty {
                    self.importFiles(newURLs, selectFirst: false)
                }
                Log.info("Karten-Sync \"\(volumeName)\": \(newURLs.count) importiert, \(failedCount) fehlgeschlagen, \(freedCount) von der Karte gelöscht")
                if failedCount > 0 || keptCount > 0 {
                    let alert = NSAlert()
                    alert.messageText = "Synchronisation mit Hinweisen abgeschlossen"
                    var lines = ["\(newURLs.count) neue Bilder importiert."]
                    if failedCount > 0 { lines.append("\(failedCount) Dateien konnten nicht kopiert werden.") }
                    if keptCount > 0 { lines.append("\(keptCount) Dateien blieben auf der Karte (nicht in der Bibliothek verifiziert).") }
                    alert.informativeText = lines.joined(separator: "\n")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func imageFiles(on url: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var found: [URL] = []
        for case let fileURL as URL in enumerator {
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
               ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                found.append(fileURL)
            }
        }
        return found
    }

    func ejectVolume(_ volume: DetectedVolume) {
        try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
    }
}
