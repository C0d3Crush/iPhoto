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
            // Grouping-Key priorisiert (in dieser Reihenfolge):
            //   1. pHash + Dateigröße — greift auch bei Exports ohne EXIF und bit-exakten Kopien
            //   2. DateTimeOriginal + Dateigröße — Fallback, falls pHash noch nicht gescannt
            //   3. Dateigröße + Dateiname (lowercased) — letzter Fallback für Kopien ohne Metadaten
            // Alle 3 Wege sind unabhängig; findet ein Bild via Weg 1 einen Partner,
            // reicht das — keine Notwendigkeit für dupliziertes Grouping.
            var byKey: [String: [ImageDocument]] = [:]
            for (i, doc) in docs.enumerated() {
                let size = (try? doc.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap({ $0 }) ?? 0
                let key: String
                if let ph = doc.phash, size > 0 {
                    key = "ph:\(ph)|\(size)"
                } else if let dateTaken = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value,
                          !dateTaken.isEmpty, size > 0 {
                    key = "dt:\(dateTaken)|\(size)"
                } else if size > 0 {
                    key = "nm:\(size)|\(doc.filename.lowercased())"
                } else {
                    let done = i + 1
                    if done % 25 == 0 || done == docs.count {
                        DispatchQueue.main.async { [weak self] in
                            self?.activity.update(id: taskID, done: done, total: docs.count)
                        }
                    }
                    continue
                }
                byKey[key, default: []].append(doc)
                let done = i + 1
                if done % 25 == 0 || done == docs.count {
                    DispatchQueue.main.async { [weak self] in
                        self?.activity.update(id: taskID, done: done, total: docs.count)
                    }
                }
            }
            let groups = byKey.values
                .filter { $0.count > 1 }
                .map { $0.sorted { $0.url.path < $1.url.path } }
                .sorted { $0[0].filename < $1[0].filename }
            Log.info("Duplikate: \(groups.count) Gruppen aus \(docs.count) Bildern (pHash-Coverage: \(docs.filter { $0.phash != nil }.count)/\(docs.count))")
            let paths = groups.map { $0.map { $0.url.path } }
            CatalogStore.shared.setDuplicateGroups(paths)
            DispatchQueue.main.async { [weak self] in
                self?.quality.duplicateGroups = groups
                self?.activity.dequeue(id: taskID)
            }
        }
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
        var blurry: [ImageDocument] = []
        var under:  [ImageDocument] = []
        var over:   [ImageDocument] = []
        for doc in docs {
            if !doc.blurOverride,  let s = doc.blurScore,  s <  blurT  { blurry.append(doc) }
            if !doc.underOverride, let r = doc.underRatio, r >= shadT  { under.append(doc)  }
            if !doc.overOverride,  let r = doc.overRatio,  r >= highT  { over.append(doc)   }
        }
        quality.blurryDocuments       = blurry.sorted { $0.filename < $1.filename }
        quality.underexposedDocuments = under.sorted  { $0.filename < $1.filename }
        quality.overexposedDocuments  = over.sorted   { $0.filename < $1.filename }
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

    /// Ähnliche-Bilder-Erkennung via pHash + Union-Find. Nutzt bereits persistierte
    /// Hashes (vom Import-Scan) — kein neuer Decode nötig.
    func detectSimilarImages() {
        let docs = collection.documents.filter { !$0.isTrashed && $0.phash != nil }
        guard docs.count > 1 else { quality.similarGroups = []; return }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Ähnliche Bilder gruppieren…",
                         icon: "square.on.square.dashed",
                         done: 0, total: docs.count, summaryVerb: "gruppiert")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let groups = SimilarityGrouper.groups(from: docs)
            let paths = groups.map { $0.map { $0.url.path } }
            CatalogStore.shared.setSimilarGroups(paths)
            DispatchQueue.main.async {
                self?.quality.similarGroups = groups
                self?.activity.dequeue(id: taskID)
            }
        }
    }

    /// Für Thumbnail-Badges: wendet aktuelle Schwellenwerte + Overrides an, ohne die
    /// Listen zu berühren. Nil-Werte (noch nicht gescannt) zählen als "kein Flag".
    func qualityFlags(for doc: ImageDocument) -> (blur: Bool, under: Bool, over: Bool) {
        guard doc.qualityScanned else { return (false, false, false) }
        let blur  = !doc.blurOverride  && (doc.blurScore  ?? .infinity) <  quality.blurThreshold
        let under = !doc.underOverride && (doc.underRatio ?? 0)         >= quality.shadowClipThreshold
        let over  = !doc.overOverride  && (doc.overRatio  ?? 0)         >= quality.highlightClipThreshold
        return (blur, under, over)
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
}
