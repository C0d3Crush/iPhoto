import AppKit
import Foundation

// Bildanalyse (Duplikate, Unschärfe, Belichtung) — nicht Teil der Lade-Pipeline,
// sondern Auswertungen auf bereits geladene Dokumente/Thumbnails.
//
// v1.7.0: Blur/Belichtung leiten die Listen aus den beim Import gescannten und in
// CatalogStore persistierten Werten ab (ImageDocument.blurScore/underRatio/overRatio).
// Nur duplicate detection scannt noch On-Demand — das läuft ausschließlich auf
// EXIF-Metadaten (DateTimeOriginal + Dateigröße).
extension ImageViewModel {

    func detectDuplicates() {
        let docs = collection.documents.filter { !$0.isTrashed }
        guard docs.count > 1 else {
            quality.duplicateGroups = []
            return
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Duplikate suchen…",
                         icon: "square.on.square",
                         done: 0, total: docs.count, summaryVerb: "geprüft")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Multi-Key-Bucketing + Union-Find: jeder Doc trägt bis zu 3 unabhängige
            // Signale bei; teilen sich zwei Docs *irgendeinen* Bucket, gelten sie als
            // Duplikat-Kandidaten. Historisch v1.8.0: exklusive Keys (ph→dt→nm) — dabei
            // fielen Docs auseinander, wenn nur eines der beiden bereits pHash hatte
            // und das andere nur Filename+Size — sie landeten in verschiedenen Tiers.
            //
            //   Signale:
            //     A. pHash (exakter Match, hash-only — Größe bewusst *nicht* mit im Key,
            //        damit re-encodete Kopien trotz abweichender Bytes matchen)
            //     B. Dateigröße + Dateiname (lowercased) — fängt einfache Kopien
            //     C. EXIF DateTimeOriginal + Größe — fängt Kamera-JPGs
            //
            // Für Verifikation lesen wir bei Kandidaten-Gruppen anschließend die ersten
            // 256 KB per SHA-256 und splitten Gruppen, deren Bytes definitiv abweichen.
            let n = docs.count
            var parent = Array(0..<n)
            func find(_ x: Int) -> Int {
                var r = x
                while parent[r] != r { r = parent[r] }
                var i = x
                while parent[i] != r { let nx = parent[i]; parent[i] = r; i = nx }
                return r
            }
            func union(_ a: Int, _ b: Int) {
                let ra = find(a), rb = find(b)
                if ra != rb { parent[rb] = ra }
            }

            var byKey: [String: [Int]] = [:]
            var sizes: [Int] = Array(repeating: 0, count: n)
            for (idx, doc) in docs.enumerated() {
                let size = (try? doc.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap({ $0 }) ?? 0
                sizes[idx] = size
                if let ph = doc.phash {
                    byKey["ph:\(ph)", default: []].append(idx)
                }
                if size > 0 {
                    byKey["fn:\(size)|\(doc.filename.lowercased())", default: []].append(idx)
                    if let dateTaken = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value,
                       !dateTaken.isEmpty {
                        byKey["dt:\(dateTaken)|\(size)", default: []].append(idx)
                    }
                }
                let done = idx + 1
                if done % 50 == 0 || done == n {
                    DispatchQueue.main.async { [weak self] in
                        self?.activity.update(id: taskID, done: done / 2, total: n)
                    }
                }
            }
            for indices in byKey.values where indices.count > 1 {
                let base = indices[0]
                for i in 1..<indices.count { union(base, indices[i]) }
            }

            // Kandidaten-Gruppen sammeln
            var buckets: [Int: [Int]] = [:]
            for i in 0..<n { buckets[find(i), default: []].append(i) }
            let candidates = buckets.values.filter { $0.count > 1 }

            // Verifikation: erste 256 KB pro Datei hashen, Gruppen splitten wo Bytes
            // definitiv abweichen. Datei-Öffnen ist schnell (~ms pro File), so bekommt
            // der Nutzer echte Fortschritts-Anzeige und die Duplikat-Aussage ist belastbar.
            var verified: [[ImageDocument]] = []
            let filesToHash = candidates.reduce(0) { $0 + $1.count }
            var hashed = 0
            for group in candidates {
                var byContent: [String: [Int]] = [:]
                for idx in group {
                    let sig = Self.contentSignature(url: docs[idx].url, size: sizes[idx])
                    byContent[sig, default: []].append(idx)
                    hashed += 1
                    if hashed % 20 == 0 || hashed == filesToHash {
                        let mid = n / 2
                        let extra = filesToHash > 0 ? (n - mid) * hashed / filesToHash : (n - mid)
                        let progress = mid + extra
                        DispatchQueue.main.async { [weak self] in
                            self?.activity.update(id: taskID, done: progress, total: n)
                        }
                    }
                }
                for sub in byContent.values where sub.count > 1 {
                    let subDocs = sub.map { docs[$0] }.sorted { $0.url.path < $1.url.path }
                    verified.append(subDocs)
                }
            }

            let groups = verified.sorted { $0[0].filename < $1[0].filename }
            let pHashCoverage = docs.filter { $0.phash != nil }.count
            Log.info("Duplikate: \(groups.count) verifizierte Gruppen aus \(candidates.count) Kandidaten (pHash-Coverage: \(pHashCoverage)/\(n))")
            let paths = groups.map { $0.map { $0.url.path } }
            CatalogStore.shared.setDuplicateGroups(paths)
            DispatchQueue.main.async { [weak self] in
                self?.quality.duplicateGroups = groups
                self?.activity.dequeue(id: taskID)
            }
        }
    }

    // 256-KB-Head-Hash: schnell genug für tausende Dateien, präzise genug um zwei
    // Bilder mit identischem pHash aber wirklich unterschiedlichem Inhalt zu trennen
    // (JPEG-Header + erste DCT-Blöcke differieren garantiert wenn Motive verschieden).
    // Fällt der Read fehl (Berechtigung, Netzlaufwerk offline), liefern wir eine
    // Path-basierte Signatur — der Doc bleibt so isoliert, statt fälschlich zu matchen.
    private static func contentSignature(url: URL, size: Int) -> String {
        let head = 256 * 1024
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return "err:\(url.path)"
        }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: head)
        var hasher = Hasher()
        hasher.combine(size)
        hasher.combine(data)
        return "sig:\(size)|\(hasher.finalize())"
    }

    /// Lädt beim App-Start die zuletzt persistierten Duplikat-/Similarity-Gruppen aus
    /// dem Katalog und mappt sie auf die aktuell geladenen Documents. Fehlt ein Pfad
    /// (Bild gelöscht/nicht mehr im Import), wird die Gruppe entsprechend verkürzt;
    /// Gruppen mit weniger als 2 verbleibenden Docs fallen raus. Neue Scans werden
    /// erst durch expliziten Nutzer-Aufruf oder `scan*ForLibrary()` ausgelöst — hier
    /// nur der Load, damit die Ansichten nach Neustart sofort gefüllt sind.
    func loadPersistedGroupsIfAvailable() {
        let byPath = Dictionary(collection.documents.map { ($0.url.path, $0) },
                                uniquingKeysWith: { a, _ in a })
        let dupPaths = CatalogStore.shared.loadDuplicateGroups()
        let simPaths = CatalogStore.shared.loadSimilarGroups()
        let dupGroups = dupPaths
            .map { grp in grp.compactMap { byPath[$0] } }
            .filter { $0.count > 1 }
            .map { $0.sorted { $0.url.path < $1.url.path } }
            .sorted { $0[0].filename < $1[0].filename }
        let simGroups = simPaths
            .map { grp in grp.compactMap { byPath[$0] } }
            .filter { $0.count > 1 }
        quality.duplicateGroups = dupGroups
        quality.similarGroups = simGroups
        Log.info("Persistierte Gruppen geladen: \(dupGroups.count) Duplikate, \(simGroups.count) Similar")
    }

    /// Aktualisiert blurry/under/over-Listen aus den beim Import persistierten Werten.
    /// Berücksichtigt Overrides (Nutzer hat "doch OK" gewählt) und die aktuellen
    /// Schwellenwerte. Ruft *keinen* neuen Scan aus — dafür `scanQualityForLibrary()`.
    func refreshQualityLists() {
        let docs = collection.documents.filter { !$0.isTrashed && $0.qualityScanned }
        let blurT = quality.blurThreshold
        let shadT = quality.shadowClipThreshold
        let highT = quality.highlightClipThreshold
        let eyeT  = quality.eyeOpennessThreshold
        var blurry: [ImageDocument] = []
        var under:  [ImageDocument] = []
        var over:   [ImageDocument] = []
        var eyes:   [ImageDocument] = []
        for doc in docs {
            if !doc.blurOverride,  let s = doc.blurScore,  s <  blurT  { blurry.append(doc) }
            if !doc.underOverride, let r = doc.underRatio, r >= shadT  { under.append(doc)  }
            if !doc.overOverride,  let r = doc.overRatio,  r >= highT  { over.append(doc)   }
            if !doc.eyesClosedOverride, let e = doc.eyeOpenness, e < eyeT { eyes.append(doc) }
        }
        quality.blurryDocuments       = blurry.sorted { $0.filename < $1.filename }
        quality.underexposedDocuments = under.sorted  { $0.filename < $1.filename }
        quality.overexposedDocuments  = over.sorted   { $0.filename < $1.filename }
        quality.closedEyeDocuments    = eyes.sorted   { $0.filename < $1.filename }
    }

    /// Kompatibilitäts-Wrapper für Views, die weiterhin "Neu scannen" auslösen: leitet
    /// die Ableitung aus persistierten Werten an + kickt einen neuen Scan an, falls
    /// noch nicht analysierte Bilder existieren.
    func detectBlurryImages() {
        refreshQualityLists()
        scanQualityForLibrary()
    }

    func detectExposureIssues() {
        refreshQualityLists()
        scanQualityForLibrary()
    }

    func detectClosedEyes() {
        refreshQualityLists()
        scanQualityForLibrary()
    }

    /// Ähnliche-Bilder-Erkennung via pHash + Seed-and-Pull. Nutzt bereits persistierte
    /// Hashes (vom Import-Scan) — kein neuer Decode nötig. Fehlt für den Großteil der
    /// Bilder noch der Hash, wird ein Quality-Scan angestoßen (Fortschritt via activity),
    /// damit "Neu gruppieren" nicht stumm ins Leere läuft.
    func detectSimilarImages() {
        let live = collection.documents.filter { !$0.isTrashed }
        let docs = live.filter { $0.phash != nil }
        guard docs.count > 1 else {
            quality.similarGroups = []
            if !live.isEmpty {
                Log.info("Ähnliche Bilder: pHash fehlt (\(docs.count)/\(live.count)) — starte Quality-Scan")
                scanQualityForLibrary()
            }
            return
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Ähnliche Bilder gruppieren…",
                         icon: "square.on.square.dashed",
                         done: 0, total: docs.count, summaryVerb: "gruppiert")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let groups = SimilarityGrouper.groups(from: docs)
            let paths = groups.map { $0.map { $0.url.path } }
            CatalogStore.shared.setSimilarGroups(paths)
            Log.info("Ähnliche Bilder: \(groups.count) Gruppen aus \(docs.count) Bildern (Ø \(groups.isEmpty ? 0 : groups.reduce(0) { $0 + $1.count } / groups.count) pro Gruppe)")
            DispatchQueue.main.async {
                self?.quality.similarGroups = groups
                self?.activity.dequeue(id: taskID)
            }
        }
    }

    /// Für Thumbnail-Badges: wendet aktuelle Schwellenwerte + Overrides an, ohne die
    /// Listen zu berühren. Nil-Werte (noch nicht gescannt) zählen als "kein Flag".
    func qualityFlags(for doc: ImageDocument) -> (blur: Bool, under: Bool, over: Bool, eyes: Bool) {
        guard doc.qualityScanned else { return (false, false, false, false) }
        let blur  = !doc.blurOverride       && (doc.blurScore   ?? .infinity) <  quality.blurThreshold
        let under = !doc.underOverride      && (doc.underRatio  ?? 0)         >= quality.shadowClipThreshold
        let over  = !doc.overOverride       && (doc.overRatio   ?? 0)         >= quality.highlightClipThreshold
        // Nil eyeOpenness heißt: kein Gesicht erkannt — nicht flaggen.
        let eyes  = !doc.eyesClosedOverride && (doc.eyeOpenness ?? .infinity) <  quality.eyeOpennessThreshold
        return (blur, under, over, eyes)
    }

    // Nutzer-Override: "Doch nicht unscharf/unter-/überbelichtet". Persistiert das Flag
    // im Katalog, updated die in-memory Kopie, verschiebt den globalen Schwellenwert
    // Richtung Bild-Score (Gewicht 0.1) — so lernt der Detektor mit der Zeit die
    // Präferenzen des Nutzers. Umkehr via override=false setzt die Klassifikation zurück.
    private static let overrideLearningWeight: Double = 0.1

    func setBlurOverride(_ value: Bool, for doc: ImageDocument) {
        guard let idx = collectionIndex(for: doc) else { return }
        collection.documents[idx].blurOverride = value
        CatalogStore.shared.setQualityOverride(path: doc.url.path, blur: value)
        if value, let score = doc.blurScore {
            let old = quality.blurThreshold
            let new = (1 - Self.overrideLearningWeight) * old + Self.overrideLearningWeight * score
            quality.blurThreshold = new
            Log.info("Blur-Override: \(doc.filename) score=\(String(format: "%.1f", score)) — Threshold \(String(format: "%.1f", old)) → \(String(format: "%.1f", new))")
        } else {
            Log.info("Blur-Override zurückgesetzt: \(doc.filename)")
        }
        refreshQualityLists()
    }

    func setUnderExposureOverride(_ value: Bool, for doc: ImageDocument) {
        guard let idx = collectionIndex(for: doc) else { return }
        collection.documents[idx].underOverride = value
        CatalogStore.shared.setQualityOverride(path: doc.url.path, under: value)
        if value, let ratio = doc.underRatio {
            let old = quality.shadowClipThreshold
            let new = (1 - Self.overrideLearningWeight) * old + Self.overrideLearningWeight * ratio
            quality.shadowClipThreshold = min(0.30, new)
            Log.info("Under-Override: \(doc.filename) ratio=\(String(format: "%.3f", ratio)) — Threshold \(String(format: "%.3f", old)) → \(String(format: "%.3f", new))")
        } else {
            Log.info("Under-Override zurückgesetzt: \(doc.filename)")
        }
        refreshQualityLists()
    }

    func setOverExposureOverride(_ value: Bool, for doc: ImageDocument) {
        guard let idx = collectionIndex(for: doc) else { return }
        collection.documents[idx].overOverride = value
        CatalogStore.shared.setQualityOverride(path: doc.url.path, over: value)
        if value, let ratio = doc.overRatio {
            let old = quality.highlightClipThreshold
            let new = (1 - Self.overrideLearningWeight) * old + Self.overrideLearningWeight * ratio
            quality.highlightClipThreshold = min(0.30, new)
            Log.info("Over-Override: \(doc.filename) ratio=\(String(format: "%.3f", ratio)) — Threshold \(String(format: "%.3f", old)) → \(String(format: "%.3f", new))")
        } else {
            Log.info("Over-Override zurückgesetzt: \(doc.filename)")
        }
        refreshQualityLists()
    }

    func setEyesClosedOverride(_ value: Bool, for doc: ImageDocument) {
        guard let idx = collectionIndex(for: doc) else { return }
        collection.documents[idx].eyesClosedOverride = value
        CatalogStore.shared.setQualityOverride(path: doc.url.path, eyesClosed: value)
        if value, let ear = doc.eyeOpenness {
            // Threshold Richtung Bild-EAR ziehen — Nutzer sagt "diese Augen sind offen",
            // also Grenze runter (weniger streng). Deckel auf 0.30, sonst degeneriert.
            let old = quality.eyeOpennessThreshold
            let new = (1 - Self.overrideLearningWeight) * old + Self.overrideLearningWeight * ear
            quality.eyeOpennessThreshold = min(0.30, new)
            Log.info("EyesClosed-Override: \(doc.filename) ear=\(String(format: "%.3f", ear)) — Threshold \(String(format: "%.3f", old)) → \(String(format: "%.3f", new))")
        } else {
            Log.info("EyesClosed-Override zurückgesetzt: \(doc.filename)")
        }
        refreshQualityLists()
    }
}
