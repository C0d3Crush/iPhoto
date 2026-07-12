import Foundation
import Combine

/// State der Datei-Versionshistorie (Speichern in Datei, Undo/Redo über
/// VersionStore-Backups) und ungespeicherter Metadaten-Änderungen.
/// Die Speicher-Orchestrierung bleibt in ImageViewModel+Save.
final class VersionHistoryState: ObservableObject {
    @Published var savedVersions: [ImageVersionMeta] = []
    @Published var showHistory: Bool = false
    @Published var isSavingToFile: Bool = false
    @Published var undoStack: [ImageVersionMeta] = []
    @Published var redoStack: [ImageVersionMeta] = []
    @Published var pendingMetadataEntries: [MetadataEntry]? = nil
}
