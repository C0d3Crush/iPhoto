import Foundation

struct CardSyncResult {
    var copied: [URL]
    var failed: Int
    var freed: Int
    var kept: Int
}

enum CardSync {
    // True iff both files have byte-identical contents (streamed in 1 MB blocks).
    static func fileContentsEqual(_ a: URL, _ b: URL) -> Bool {
        guard let fa = try? FileHandle(forReadingFrom: a),
              let fb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? fa.close(); try? fb.close() }
        while true {
            let da = fa.readData(ofLength: 1_048_576)
            let db = fb.readData(ofLength: 1_048_576)
            if da != db { return false }
            if da.isEmpty { return true }
        }
    }

    // Returns image URLs under `root` matching `supportedExtensions`.
    static func imageFiles(on root: URL, extensions: Set<String>) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var found: [URL] = []
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
               extensions.contains(url.pathExtension.lowercased()) {
                found.append(url)
            }
        }
        return found
    }

    // Decide which source files need copying and which are already in dest.
    // "Already present" = an existing dest file (exact name or _N variant) OR a
    // file already planned in this run has the same size AND identical byte content.
    // This prevents duplicate _N suffixes on repeated syncs and handles multiple
    // source folders with identically-named files.
    static func plan(
        sourceFiles: [URL],
        dest: URL
    ) -> (toCopy: [(src: URL, dest: URL)], alreadyPresent: [String: URL]) {
        let fm = FileManager.default
        var filesToCopy: [(src: URL, dest: URL)] = []
        var alreadyPresent: [String: URL] = [:]
        // destPath → planned source URL (for in-plan duplicate detection)
        var plannedDestToSrc: [String: URL] = [:]

        for file in sourceFiles {
            let srcSize = (try? fm.attributesOfItem(atPath: file.path))?[.size] as? Int ?? -1
            let base = (file.lastPathComponent as NSString).deletingPathExtension
            let ext  = (file.lastPathComponent as NSString).pathExtension
            let exact = dest.appendingPathComponent(file.lastPathComponent)

            // 1. Check existing files on disk (exact name + _N variants)
            var candidates: [URL] = []
            if fm.fileExists(atPath: exact.path) { candidates.append(exact) }
            for n in 1...50 {
                let name = ext.isEmpty ? "\(base)_\(n)" : "\(base)_\(n).\(ext)"
                let c = dest.appendingPathComponent(name)
                if fm.fileExists(atPath: c.path) { candidates.append(c) }
            }

            var matchedDest: URL? = nil
            for candidate in candidates {
                let dstSize = (try? fm.attributesOfItem(atPath: candidate.path))?[.size] as? Int ?? -2
                if srcSize == dstSize && fileContentsEqual(file, candidate) {
                    matchedDest = candidate
                    break
                }
            }

            if let matched = matchedDest {
                alreadyPresent[file.path] = matched
                continue
            }

            // 2. Check in-plan files (same session, not yet on disk)
            if let plannedSrc = plannedDestToSrc[exact.path] {
                let plannedSize = (try? fm.attributesOfItem(atPath: plannedSrc.path))?[.size] as? Int ?? -1
                if srcSize == plannedSize && fileContentsEqual(file, plannedSrc) {
                    // Identical to already-planned file → mark as already_present (pointing to future dest)
                    alreadyPresent[file.path] = exact
                    continue
                }
            }

            // 3. Assign a unique dest path (considering both existing files and in-plan assignments)
            var targetDest = exact
            if fm.fileExists(atPath: exact.path) || plannedDestToSrc[exact.path] != nil {
                var suffix = 1
                repeat {
                    let name = ext.isEmpty ? "\(base)_\(suffix)" : "\(base)_\(suffix).\(ext)"
                    targetDest = dest.appendingPathComponent(name)
                    suffix += 1
                } while fm.fileExists(atPath: targetDest.path) || plannedDestToSrc[targetDest.path] != nil
            }

            plannedDestToSrc[targetDest.path] = file
            filesToCopy.append((src: file, dest: targetDest))
        }

        return (toCopy: filesToCopy, alreadyPresent: alreadyPresent)
    }

    // Copy planned files, verify each copy by content equality, and optionally
    // delete source files that were successfully verified in dest.
    static func execute(
        sourceFiles: [URL],
        toCopy: [(src: URL, dest: URL)],
        alreadyPresent: [String: URL],
        freeUpSpace: Bool,
        progress: ((Int, Int) -> Void)? = nil
    ) -> CardSyncResult {
        let fm = FileManager.default
        var newURLs: [URL] = []
        var copiedMap: [String: URL] = alreadyPresent
        var failedCount = 0
        var done = 0

        for (src, dest) in toCopy {
            if (try? fm.copyItem(at: src, to: dest)) != nil {
                if fileContentsEqual(src, dest) {
                    newURLs.append(dest)
                    copiedMap[src.path] = dest
                } else {
                    failedCount += 1
                    try? fm.removeItem(at: dest)
                }
            } else {
                failedCount += 1
            }
            done += 1
            progress?(done, toCopy.count)
        }

        var freedCount = 0
        var keptCount = 0
        if freeUpSpace {
            for file in sourceFiles {
                if copiedMap[file.path] != nil, (try? fm.removeItem(at: file)) != nil {
                    freedCount += 1
                } else if copiedMap[file.path] == nil {
                    keptCount += 1
                }
            }
        }

        return CardSyncResult(copied: newURLs, failed: failedCount, freed: freedCount, kept: keptCount)
    }
}
