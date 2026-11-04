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

    // Scannt alle noch nicht gescannten Bilder auf Gesichter.
    // Läuft im Hintergrund, Fortschritt via people.scanProgress.
    func scanFacesForLibrary() {
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
        let opts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }
}
