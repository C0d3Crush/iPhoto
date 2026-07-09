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

    func addDetectedVolumeIfRemovable(_ url: URL) {
        let vals = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeNameKey])
        guard vals?.volumeIsRemovable == true else { return }
        let name = vals?.volumeName ?? url.lastPathComponent
        let standardPath = url.standardized.path
        guard !detectedVolumes.contains(where: { $0.url.standardized.path == standardPath }) else { return }
        detectedVolumes.append(DetectedVolume(id: UUID(), name: name, url: url))
    }

    func removeDetectedVolume(at url: URL) {
        let path = url.standardized.path
        guard let idx = detectedVolumes.firstIndex(where: { $0.url.standardized.path == path }) else { return }
        let volumeID = detectedVolumes[idx].id
        detectedVolumes.remove(at: idx)
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
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: volumeURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { self.dequeueLoading(id: volumeID) }
                return
            }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.importFiles(found, selectFirst: false)
                self.dequeueLoading(id: volumeID)
            }
        }
    }

    func ejectVolume(_ volume: DetectedVolume) {
        try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
    }
}
