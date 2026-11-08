import Foundation

/// Filesystem-Spiegelung intelligenter Ordner: Symlink-Verzeichnisse unter
/// ~/Pictures/iPhoto/Intelligente Ordner. Reine, synchrone Dateisystem-Logik
/// ohne ViewModel-Bezug — Aufrufer dispatchen auf eine Utility-Queue.
enum SmartFolderFileSync {

    static let systemFolderName = "Intelligente Ordner"

    static var root: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
            .appendingPathComponent(systemFolderName)
    }

    static func systemPath(for sf: SmartFolder) -> URL {
        if let grp = sf.group, !grp.isEmpty {
            return root.appendingPathComponent(grp).appendingPathComponent(sf.name)
        }
        return root.appendingPathComponent(sf.name)
    }

    /// Bringt das Symlink-Verzeichnis eines intelligenten Ordners auf den Stand
    /// der übergebenen Treffer-URLs; entfernt optional das alte Verzeichnis
    /// (nach Umbenennen/Verschieben).
    static func sync(_ sf: SmartFolder, matchingURLs: [URL], removingOldAt oldDir: URL? = nil) {
        let matchPaths = Set(matchingURLs.map { $0.standardized.path })
        let dir = systemPath(for: sf)
        let fm = FileManager.default

        if let old = oldDir {
            try? fm.removeItem(at: old)
            // Leeres Gruppen-Verzeichnis des alten Orts entfernen
            let oldParent = old.deletingLastPathComponent()
            if oldParent.path != root.path,
               let contents = try? fm.contentsOfDirectory(atPath: oldParent.path),
               contents.isEmpty {
                try? fm.removeItem(at: oldParent)
            }
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // Veraltete Symlinks entfernen
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            for link in contents {
                guard (try? link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else { continue }
                let target = (try? fm.destinationOfSymbolicLink(atPath: link.path)).map {
                    URL(fileURLWithPath: $0).standardized.path
                }
                if target.map({ !matchPaths.contains($0) }) ?? true {
                    try? fm.removeItem(at: link)
                }
            }
        }

        // Build reverse map: target path → link name, to skip already-linked files
        var linkedTargets: [String: String] = [:]
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for link in contents {
                if let dest = try? fm.destinationOfSymbolicLink(atPath: link.path) {
                    linkedTargets[URL(fileURLWithPath: dest).standardized.path] = link.lastPathComponent
                }
            }
        }

        var existingLinks = Set(linkedTargets.values)
        for docURL in matchingURLs {
            let srcPath = docURL.standardized.path
            // Already linked under any name: nothing to do
            if linkedTargets[srcPath] != nil { continue }

            var linkName = docURL.lastPathComponent
            var counter  = 1
            while existingLinks.contains(linkName) {
                let base = (docURL.lastPathComponent as NSString).deletingPathExtension
                let ext  = (docURL.lastPathComponent as NSString).pathExtension
                linkName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
                counter += 1
            }
            let linkURL = dir.appendingPathComponent(linkName)
            if !fm.fileExists(atPath: linkURL.path, isDirectory: nil) {
                try? fm.createSymbolicLink(at: linkURL, withDestinationURL: docURL)
                existingLinks.insert(linkName)
                linkedTargets[srcPath] = linkName
            }
        }
        Log.info("iOrdner Filesystem-Sync: \"\(sf.name)\" → \(matchingURLs.count) Symlinks in \(dir.path)")
    }

    static func remove(_ sf: SmartFolder) {
        try? FileManager.default.removeItem(at: systemPath(for: sf))
        if let grp = sf.group, !grp.isEmpty {
            removeGroupDirIfEmpty(grp)
        }
    }

    static func removeGroupDirIfEmpty(_ group: String) {
        let fm = FileManager.default
        let groupDir = root.appendingPathComponent(group)
        if let contents = try? fm.contentsOfDirectory(atPath: groupDir.path), contents.isEmpty {
            try? fm.removeItem(at: groupDir)
        }
    }

    static func removeGroupDir(_ group: String) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(group))
    }

    static func moveGroupDir(from oldName: String, to newName: String) {
        let fm = FileManager.default
        let oldDir = root.appendingPathComponent(oldName)
        if fm.fileExists(atPath: oldDir.path) {
            try? fm.moveItem(at: oldDir, to: root.appendingPathComponent(newName))
        }
    }
}
