import AppKit

struct FileOpenHelper {
    static func openPanel(completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Bild öffnen"
        panel.prompt = "Öffnen"
        panel.allowedFileTypes = Array(ImageDocument.supportedExtensions)

        panel.begin { response in
            guard response == .OK else { return }
            completion(panel.urls)
        }
    }
}
