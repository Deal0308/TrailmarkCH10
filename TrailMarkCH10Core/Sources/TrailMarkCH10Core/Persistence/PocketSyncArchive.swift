import Foundation

/// Atomic manifests survive relaunch. Incoming files stay here until their
/// destination store confirms the save; retries use the payload's stable ID.
enum PocketSyncArchive {
    enum Direction: String { case incoming = "Inbox", outgoing = "Outbox" }
    struct Memo: Codable, Sendable {
        let metadata: PocketMemoMetadata
        let relativeFilename: String
    }

    static func directory(_ direction: Direction) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("TrailmarkCore/PocketSync/\(direction.rawValue)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func save(_ activity: WatchActivityRecord, direction: Direction) throws {
        let url = try directory(direction).appendingPathComponent(activity.id.uuidString + ".activity")
        try JSONEncoder().encode(activity).write(to: url, options: .atomic)
    }

    static func activities(_ direction: Direction) throws -> [WatchActivityRecord] {
        try manifests(direction, extension: "activity").map { try JSONDecoder().decode(WatchActivityRecord.self, from: Data(contentsOf: $0)) }
    }

    static func removeActivity(_ id: UUID, direction: Direction) throws {
        let url = try directory(direction).appendingPathComponent(id.uuidString + ".activity")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    static func stage(_ source: URL, metadata: PocketMemoMetadata, direction: Direction) throws -> Memo {
        let folder = try directory(direction)
        let filename = UUID().uuidString + ".m4a"
        let destination = folder.appendingPathComponent(filename)
        let memo = Memo(metadata: metadata, relativeFilename: filename)
        try FileManager.default.copyItem(at: source, to: destination)
        do { try JSONEncoder().encode(memo).write(to: destination.appendingPathExtension("memo"), options: .atomic) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return memo
    }

    static func memos(_ direction: Direction) throws -> [Memo] {
        try manifests(direction, extension: "memo").map { try JSONDecoder().decode(Memo.self, from: Data(contentsOf: $0)) }
    }

    static func fileURL(_ memo: Memo, direction: Direction) throws -> URL {
        guard memo.relativeFilename == URL(fileURLWithPath: memo.relativeFilename).lastPathComponent,
              memo.relativeFilename.hasSuffix(".m4a"),
              UUID(uuidString: String(memo.relativeFilename.dropLast(4))) != nil else {
            throw JournalMediaStore.StoreError.invalidRelativeFilename
        }
        return try directory(direction).appendingPathComponent(memo.relativeFilename)
    }

    static func removeMemo(_ memo: Memo, direction: Direction) throws {
        let file = try fileURL(memo, direction: direction)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        let manifest = file.appendingPathExtension("memo")
        if FileManager.default.fileExists(atPath: manifest.path) { try FileManager.default.removeItem(at: manifest) }
    }

    private static func manifests(_ direction: Direction, extension ext: String) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory(direction), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == ext }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
