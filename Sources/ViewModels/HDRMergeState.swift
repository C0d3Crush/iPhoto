import Foundation
import Combine

/// UI-State des HDR-Merge-Sheets. Die Merge-Orchestrierung bleibt in
/// ImageViewModel+HDR (braucht Collection, Lade-Queue und Import).
final class HDRMergeState: ObservableObject {
    @Published var showSheet: Bool = false
    @Published var isMerging: Bool = false
    @Published var error: String? = nil
    @Published var resultURL: URL? = nil
}
