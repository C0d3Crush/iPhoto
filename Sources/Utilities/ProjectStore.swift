import Foundation

class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published var projects: [Project] = []

    private var saveURL: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("projects.json")
    }

    var lastProjectID: UUID? {
        get { UserDefaults.standard.string(forKey: "project.lastID").flatMap { UUID(uuidString: $0) } }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "project.lastID") }
    }

    var lastProject: Project? { projects.first(where: { $0.id == lastProjectID }) }

    private init() { load() }

    @discardableResult
    func createProject(name: String, folderPaths: [String]) -> Project {
        let p = Project(name: name, folderPaths: folderPaths)
        projects.append(p)
        save()
        return p
    }

    func updateProject(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx] = project
        save()
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if lastProjectID == project.id { lastProjectID = nil }
        save()
    }

    func setLastOpened(_ project: Project) {
        lastProjectID = project.id
        var p = project
        p.lastOpenedAt = Date()
        updateProject(p)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: saveURL)
    }

    func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else { return }
        projects = decoded
    }
}
