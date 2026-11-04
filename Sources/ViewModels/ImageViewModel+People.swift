import AppKit
import Foundation

extension ImageViewModel {

    // Lädt alle gespeicherten People + Faces aus dem Katalog und befüllt people-State.
    func loadPeople() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let allPeople = CatalogStore.shared.allPeople()
            let allFaces  = CatalogStore.shared.allFaces()

            var byPerson: [String: [FaceRecord]] = [:]
            var unassigned: [FaceRecord] = []
            for face in allFaces {
                if let cid = face.clusterID {
                    byPerson[cid, default: []].append(face)
                } else {
                    unassigned.append(face)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.people.people       = allPeople
                self?.people.facesPerPerson = byPerson
                self?.people.unassignedFaces = unassigned
            }
        }
    }

    // Scannt alle noch nicht gescannten Bilder auf Gesichter, dann direkt clustern.
    func scanFacesForLibrary() {
        scanAndClusterFaces()
    }

    // Nur Scan, kein automatisches Clustering (intern).
    private func scanFacesOnly() {
        guard !people.isScanning else { return }
        DispatchQueue.main.async { [weak self] in
            self?.people.isScanning   = true
            self?.people.scanProgress = 0
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Gesichter scannen…",
                         icon: "person.crop.rectangle",
                         done: 0, total: 0, summaryVerb: "gescannt")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let paths = CatalogStore.shared.pathsNeedingFaceScan()
            let total = paths.count
            if total == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.people.isScanning   = false
                    self?.people.scanProgress = 1.0
                }
                DispatchQueue.main.async { self.activity.dequeue(id: taskID) }
                self.loadPeople()
                return
            }
            DispatchQueue.main.async { [weak self] in self?.activity.update(id: taskID, done: 0, total: total) }

            for (idx, path) in paths.enumerated() {
                autoreleasepool {
                    if let cgImage = self.loadThumbnailCGImage(path: path) {
                        let faces = FaceDetector.detect(in: cgImage, imagePath: path)
                        if !faces.isEmpty {
                            CatalogStore.shared.insertFaces(faces)
                        }
                    }
                    CatalogStore.shared.markFaceScanned(path: path)
                }
                let done = idx + 1
                let progress = Double(done) / Double(total)
                if done % 10 == 0 || done == total {
                    DispatchQueue.main.async { [weak self] in
                        self?.people.scanProgress = progress
                        self?.activity.update(id: taskID, done: done, total: total)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.people.isScanning   = false
                self?.people.scanProgress = 1.0
            }
            DispatchQueue.main.async { self.activity.dequeue(id: taskID) }
            self.loadPeople()
        }
    }

    // Erstellt eine neue Person und gibt sie zurück.
    @discardableResult
    func createPerson(name: String) -> PersonRecord {
        let person = PersonRecord(id: UUID().uuidString, name: name, coverFaceID: nil)
        CatalogStore.shared.insertPerson(person)
        DispatchQueue.main.async { [weak self] in
            self?.people.people.append(person)
        }
        return person
    }

    func renamePerson(_ person: PersonRecord, to name: String) {
        var updated = person
        updated.name = name
        CatalogStore.shared.updatePerson(updated)
        DispatchQueue.main.async { [weak self] in
            if let idx = self?.people.people.firstIndex(where: { $0.id == person.id }) {
                self?.people.people[idx] = updated
            }
        }
    }

    func deletePerson(_ person: PersonRecord) {
        CatalogStore.shared.deletePerson(id: person.id)
        DispatchQueue.main.async { [weak self] in
            self?.people.people.removeAll { $0.id == person.id }
            self?.people.facesPerPerson.removeValue(forKey: person.id)
            let freed = self?.people.facesPerPerson[person.id] ?? []
            self?.people.unassignedFaces.append(contentsOf: freed)
        }
    }

    // MARK: - Clustering

    // Wendet DBSCAN auf alle Gesicht-Embeddings an und weist Faces Personen zu.
    // Bestehende benannte Personen werden beibehalten — ihre Cluster-Zugehörigkeit
    // wird auf den neuen Clustering-Ergebnissen abgeglichen.
    // Aufruf: nach scanFacesForLibrary() oder auf expliziten Nutzer-Wunsch.
    func clusterFaces() {
        guard !people.isScanning else { return }
        DispatchQueue.main.async { [weak self] in
            self?.people.isScanning   = true
            self?.people.scanProgress = 0
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Gesichter gruppieren…",
                         icon: "person.3", done: 0, total: 0, summaryVerb: "gruppiert")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let allFaces = CatalogStore.shared.allFaces()
            guard !allFaces.isEmpty else {
                DispatchQueue.main.async {
                    self.people.isScanning = false
                    self.activity.dequeue(id: taskID)
                }
                return
            }

            // --- DBSCAN ---
            let clusterMap = FaceClusterer.cluster(faces: allFaces)
            // clusterMap: faceID → clusterIndex (≥0) or -1 (noise)

            // --- Benannte Personen schützen ---
            // Für jede existierende benannte Person: ermittle welchen neuen Cluster
            // ihre Faces am häufigsten belegen → dieser Cluster wird "ihre" Cluster-ID.
            let existingNamed = CatalogStore.shared.allPeople().filter { $0.name != nil }
            var clusterIndexToPerson = [Int: PersonRecord]()

            for person in existingNamed {
                var votes = [Int: Int]()
                for face in allFaces where face.clusterID == person.id {
                    if let ci = clusterMap[face.id], ci >= 0 {
                        votes[ci, default: 0] += 1
                    }
                }
                if let best = votes.max(by: { $0.value < $1.value })?.key {
                    clusterIndexToPerson[best] = person
                }
            }

            // --- Unbenannte Personen entfernen, neu erstellen ---
            CatalogStore.shared.deleteAutoGeneratedPeople()

            // --- Cluster → PersonRecord zuordnen ---
            var uniqueClusters = Set(clusterMap.values.filter { $0 >= 0 })
            var assignments = [String: String?]()

            for ci in uniqueClusters {
                let clusterFaces = allFaces.filter { clusterMap[$0.id] == ci }
                let person: PersonRecord
                if let existing = clusterIndexToPerson[ci] {
                    person = existing
                } else {
                    let coverID = clusterFaces.first?.id
                    let new = PersonRecord(id: UUID().uuidString, name: nil, coverFaceID: coverID)
                    CatalogStore.shared.insertPerson(new)
                    person = new
                }
                for face in clusterFaces {
                    assignments[face.id] = person.id
                }
            }

            // Noise-Faces (clusterIndex = -1) → unzugeordnet
            for face in allFaces where (clusterMap[face.id] ?? -1) < 0 {
                assignments[face.id] = nil
            }

            CatalogStore.shared.batchUpdateFaceClusters(assignments)

            DispatchQueue.main.async { [weak self] in
                self?.people.isScanning   = false
                self?.people.scanProgress = 1.0
            }
            self.activity.dequeue(id: taskID)
            self.loadPeople()
        }
    }

    // Scan + anschließendes Clustering in einem Schritt.
    func scanAndClusterFaces() {
        guard !people.isScanning else { return }
        DispatchQueue.main.async { [weak self] in
            self?.people.isScanning   = true
            self?.people.scanProgress = 0
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Gesichter scannen & gruppieren…",
                         icon: "person.crop.rectangle",
                         done: 0, total: 0, summaryVerb: "verarbeitet")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Phase 1: Scan
            let paths = CatalogStore.shared.pathsNeedingFaceScan()
            let total = paths.count
            if total > 0 {
                DispatchQueue.main.async { self.activity.update(id: taskID, done: 0, total: total + 1) }
                for (idx, path) in paths.enumerated() {
                    autoreleasepool {
                        if let cg = self.loadThumbnailCGImage(path: path) {
                            let faces = FaceDetector.detect(in: cg, imagePath: path)
                            if !faces.isEmpty { CatalogStore.shared.insertFaces(faces) }
                        }
                        CatalogStore.shared.markFaceScanned(path: path)
                    }
                    let done = idx + 1
                    let progress = Double(done) / Double(total + 1)
                    if done % 10 == 0 || done == total {
                        DispatchQueue.main.async { [weak self] in
                            self?.people.scanProgress = progress * 0.8
                            self?.activity.update(id: taskID, done: done, total: total + 1)
                        }
                    }
                }
            }

            // Phase 2: Cluster
            DispatchQueue.main.async { self.activity.update(id: taskID, done: total, total: total + 1) }
            let allFaces = CatalogStore.shared.allFaces()
            if !allFaces.isEmpty {
                let clusterMap = FaceClusterer.cluster(faces: allFaces)
                let existingNamed = CatalogStore.shared.allPeople().filter { $0.name != nil }
                var clusterIndexToPerson = [Int: PersonRecord]()
                for person in existingNamed {
                    var votes = [Int: Int]()
                    for face in allFaces where face.clusterID == person.id {
                        if let ci = clusterMap[face.id], ci >= 0 { votes[ci, default: 0] += 1 }
                    }
                    if let best = votes.max(by: { $0.value < $1.value })?.key {
                        clusterIndexToPerson[best] = person
                    }
                }
                CatalogStore.shared.deleteAutoGeneratedPeople()

                var assignments = [String: String?]()
                let clusters = Set(clusterMap.values.filter { $0 >= 0 })
                for ci in clusters {
                    let cFaces = allFaces.filter { clusterMap[$0.id] == ci }
                    let person: PersonRecord
                    if let existing = clusterIndexToPerson[ci] {
                        person = existing
                    } else {
                        let new = PersonRecord(id: UUID().uuidString, name: nil, coverFaceID: cFaces.first?.id)
                        CatalogStore.shared.insertPerson(new)
                        person = new
                    }
                    for face in cFaces { assignments[face.id] = person.id }
                }
                for face in allFaces where (clusterMap[face.id] ?? -1) < 0 { assignments[face.id] = nil }
                CatalogStore.shared.batchUpdateFaceClusters(assignments)
            }

            DispatchQueue.main.async { [weak self] in
                self?.people.isScanning   = false
                self?.people.scanProgress = 1.0
            }
            self.activity.dequeue(id: taskID)
            self.loadPeople()
        }
    }

    // Führt zwei Personen zusammen: alle Faces von `other` werden `into` zugewiesen,
    // `other` wird gelöscht.
    func mergePersons(into target: PersonRecord, other: PersonRecord) {
        guard target.id != other.id else { return }
        let otherFaces = people.facesPerPerson[other.id] ?? []
        let faceIDs = otherFaces.map { $0.id }
        let assignments: [String: String?] = Dictionary(uniqueKeysWithValues: faceIDs.map { ($0, target.id) })
        CatalogStore.shared.batchUpdateFaceClusters(assignments)
        CatalogStore.shared.deletePerson(id: other.id)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.people.people.removeAll { $0.id == other.id }
            var targetFaces = self.people.facesPerPerson[target.id] ?? []
            for var face in otherFaces { face.clusterID = target.id; targetFaces.append(face) }
            self.people.facesPerPerson[target.id] = targetFaces
            self.people.facesPerPerson.removeValue(forKey: other.id)
        }
    }

    func assignFace(faceID: String, toPersonID personID: String) {
        CatalogStore.shared.updateFaceCluster(faceID: faceID, clusterID: personID)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let idx = self.people.unassignedFaces.firstIndex(where: { $0.id == faceID }) {
                var face = self.people.unassignedFaces.remove(at: idx)
                face.clusterID = personID
                self.people.facesPerPerson[personID, default: []].append(face)
            }
        }
    }

    // MARK: - Private helper

    private func loadThumbnailCGImage(path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // Always statt IfAbsent: eingebettete EXIF-Thumbnails (oft 160×120 px) werden ignoriert;
        // stattdessen immer aus dem vollen Bilddaten dekodiert → klare Qualität für VNDetectFaceRectanglesRequest.
        // 1024 statt 512: genug Auflösung für kleine Gesichter in Gruppenfotos.
        let opts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }
}
