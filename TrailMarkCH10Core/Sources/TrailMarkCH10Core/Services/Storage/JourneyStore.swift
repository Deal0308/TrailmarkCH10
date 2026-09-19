import Foundation

/// Main-actor serialization and atomic JSON replacement keep callers from racing writes.
@MainActor
public final class JourneyStore {
    private let indexURL: URL
    public private(set) var journeys: [Journey]

    public init(directory: URL? = nil) throws {
        let folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TrailmarkCore/Journeys", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        indexURL = folder.appendingPathComponent("journeys.json")
        if FileManager.default.fileExists(atPath: indexURL.path) {
            journeys = try JSONDecoder().decode([Journey].self, from: Data(contentsOf: indexURL))
        } else {
            journeys = []
        }
        // The process cannot still be recording after a relaunch. Preserve its last checkpoint.
        var recovered = journeys
        for index in recovered.indices where recovered[index].status == .recording {
            recovered[index].status = .interrupted
            recovered[index].endDate = recovered[index].points.last?.timestamp ?? recovered[index].startDate
        }
        if recovered != journeys { try commit(recovered) }
    }

    public func save(_ journey: Journey) throws {
        var updated = journeys
        if let index = updated.firstIndex(where: { $0.id == journey.id }) { updated[index] = journey }
        else { updated.append(journey) }
        try commit(updated)
    }

    private func commit(_ updated: [Journey]) throws {
        try JSONEncoder().encode(updated).write(to: indexURL, options: .atomic)
        journeys = updated
    }
}
