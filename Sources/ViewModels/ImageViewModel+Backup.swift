import AppKit
import Foundation

// MARK: - Backup (Kontextmenü)
//
// Zwei Varianten:
//   backupDocuments(docs, deleteOriginal: false)  → nur JPEG-Kopie schreiben
//   backupDocuments(docs, deleteOriginal: true)   → JPEG-Kopie + Original in iPhoto-Trash
//
// Aufrufer (ThumbnailContextMenu) übergibt bereits die richtige Target-Liste
// (Multi-Selection, eingeklappter Stapel). Pick-Schutz greift nur bei der
// Delete-Variante — reine Backups sind non-destruktiv und immer erlaubt.

extension ImageViewModel {

    /// Ergebnis eines Backup-Laufs, für die zusammenfassende Anzeige nach Abschluss.
    struct BackupSummary {
        var written: Int = 0
        var skipped: Int = 0
        var failed: [(filename: String, reason: String)] = []
    }

    func backupDocuments(_ docs: [ImageDocument], deleteOriginal: Bool) {
        guard !docs.isEmpty else { return }
        // Delete-Variante ist destruktiv → Pick-Schutz wie beim Trash-Pfad.
        if deleteOriginal, showPickBlockedAlertIfNeeded(docs) { return }

        let settings = self.backupSettings
        let count = docs.count
        let taskID = UUID()
        let label = deleteOriginal
            ? (count == 1 ? "Backup + Papierkorb…" : "\(count) Backups + Papierkorb…")
            : (count == 1 ? "Backup…" : "\(count) Backups…")
        activity.enqueue(id: taskID, label: label, icon: "externaldrive.badge.checkmark",
                         done: 0, total: count, summaryVerb: "gesichert")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (root, stopRoot) = settings.resolveDestination()
            defer { stopRoot() }

            var summary = BackupSummary()
            var succeededDocs: [ImageDocument] = []
            for (i, doc) in docs.enumerated() {
                // Sicherheits-Scope für die Quelle beibehalten (importierte Volumes
                // brauchen das Bookmark).
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: doc.url)
                let result = BackupService.backup(source: accessURL, root: root, settings: settings)
                stopAccess()
                switch result {
                case .written(let url):
                    summary.written += 1
                    succeededDocs.append(doc)
                    Log.info("BACKUP \(doc.filename) → \(url.path)")
                case .skipped(let url):
                    summary.skipped += 1
                    Log.info("BACKUP skip (existiert): \(doc.filename) → \(url.lastPathComponent)")
                case .failed(let reason):
                    summary.failed.append((doc.filename, reason))
                    Log.error("BACKUP fail \(doc.filename): \(reason)")
                }
                let done = i + 1
                DispatchQueue.main.async { self.activity.update(id: taskID, done: done, total: count) }
            }

            DispatchQueue.main.async {
                self.activity.dequeue(id: taskID)
                if !summary.failed.isEmpty {
                    self.showBackupFailureAlert(summary)
                }
                // Nur die tatsächlich erfolgreich gesicherten Bilder werden gelöscht —
                // fehlerhafte Backups würden sonst Original + Backup verlieren.
                if deleteOriginal, !succeededDocs.isEmpty {
                    self.moveToAppTrash(succeededDocs)
                }
            }
        }
    }

    private func showBackupFailureAlert(_ summary: BackupSummary) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = summary.failed.count == 1
            ? "1 Backup fehlgeschlagen"
            : "\(summary.failed.count) Backups fehlgeschlagen"
        let firstReasons = summary.failed.prefix(5)
            .map { "• \($0.filename): \($0.reason)" }
            .joined(separator: "\n")
        let more = summary.failed.count > 5 ? "\n…" : ""
        alert.informativeText = firstReasons + more
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Target-Auflösung fürs Kontextmenü
    //
    // Gleiche Regeln wie beim Trash-Pfad: Multi-Selection hat Vorrang, sonst
    // eingeklappte Stapel-Mitglieder, sonst nur das eine Bild.
    func backupTargets(for doc: ImageDocument) -> [ImageDocument] {
        if let idx = collectionIndex(for: doc),
           collection.selectedIndices.count > 1,
           collection.selectedIndices.contains(idx) {
            return collection.selectedIndices.sorted().compactMap {
                $0 < collection.documents.count ? collection.documents[$0] : nil
            }
        }
        if let members = collapsedStackMembers(for: doc) { return members }
        return [doc]
    }
}
