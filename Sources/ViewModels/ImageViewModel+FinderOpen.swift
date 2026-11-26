import Foundation

// MARK: - Open-with-Finder context loading

extension ImageViewModel {

    /// Handles URLs delivered by macOS "Open with iPhoto" (AppDelegate.application(_:open:)).
    /// Unlike plain importFiles(), this loads the full parent directory so the user can
    /// browse all neighbours, then navigates to the first requested URL.
    func openURLsFromFinder(_ urls: [URL]) {
        let supported = urls.filter { isSupportedFormat($0) }
        guard !supported.isEmpty else { return }
        let target = supported[0]

        // If the target is already in the collection (e.g. loaded from a watched folder),
        // just navigate — importFiles would return early without navigating.
        if let idx = collection.documentIndexByURL[target] {
            collection.select(index: idx)
            loadCurrentImage()
            return
        }

        // Enumerate all supported images in the unique parent directories so the user
        // can browse the full folder context, not just the files they right-clicked.
        let fm = FileManager.default
        var dirImages: [URL] = []
        for dir in Set(supported.map { $0.deletingLastPathComponent() }) {
            let entries = (try? fm.contentsOfDirectory(at: dir,
                                                       includingPropertiesForKeys: nil,
                                                       options: .skipsHiddenFiles)) ?? []
            dirImages += entries.filter { isSupportedFormat($0) }
        }
        let toImport = dirImages.isEmpty ? supported : dirImages
        importFiles(toImport, selectFirst: false)

        // Navigate to the target URL once the async import lands on Main.
        // 0.4 s covers the background catalog-read + main-thread append cycle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self,
                  let idx = self.collection.documentIndexByURL[target] else { return }
            self.collection.select(index: idx)
            self.loadCurrentImage()
        }
    }
}
