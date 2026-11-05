import Foundation
import Combine

final class PeopleState: ObservableObject {
    @Published var people: [PersonRecord] = []          { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var unassignedFaces: [FaceRecord] = []   { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var facesPerPerson: [String: [FaceRecord]] = [:]  { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0

    var totalFaceCount: Int {
        facesPerPerson.values.reduce(0) { $0 + $1.count } + unassignedFaces.count
    }
}
