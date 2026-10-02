import Foundation

/// Every access to the index is protected by the lock. Filenames stay relative to Application Support.
public final class JournalMediaStore: @unchecked Sendable {
    public enum StoreError: LocalizedError {
        case invalidRelativeFilename, invalidDuration, sourceFileMissing, mediaNotFound
        public var errorDescription: String? {
            switch self {
            case .invalidRelativeFilename: "The media filename is invalid."
            case .invalidDuration: "A memo must have a valid duration greater than zero."
            case .sourceFileMissing: "The captured media file is missing."
            case .mediaNotFound: "This memo's file is no longer available."
            }
        }
    }
    private let lock = NSRecursiveLock()
    private let fileManager: FileManager
    private let directoryURL: URL
    private let indexURL: URL
    private var items: [JournalMedia]

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.directoryURL = try directoryURL ?? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("TrailmarkCore/Media", isDirectory: true)
        indexURL = self.directoryURL.appendingPathComponent("media-index.json")
        try fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        // Corrupt metadata is surfaced for recovery instead of silently replacing it with an empty index.
        if fileManager.fileExists(atPath: indexURL.path) {
            items = try JSONDecoder().decode([JournalMedia].self, from: Data(contentsOf: indexURL))
        } else { items = [] }
        // Complete or roll back a deletion interrupted between the two on-disk operations.
        for file in try fileManager.contentsOfDirectory(at: self.directoryURL, includingPropertiesForKeys: nil) where file.pathExtension == "pending-delete" {
            let original = file.deletingPathExtension()
            if items.contains(where: { $0.relativeFilename == original.lastPathComponent }) {
                if !fileManager.fileExists(atPath: original.path) { try fileManager.moveItem(at: file, to: original) }
            } else { try fileManager.removeItem(at: file) }
        }
        // A crash after copying but before indexing an import can leave an unindexed file.
        // Only remove our UUID-named files from this private store directory.
        let indexed = Set(items.map(\.relativeFilename))
        for file in try fileManager.contentsOfDirectory(at: self.directoryURL, includingPropertiesForKeys: nil) {
            if UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
               file.pathExtension != "pending-delete", !indexed.contains(file.lastPathComponent) {
                try fileManager.removeItem(at: file)
            }
        }
    }

    public var media: [JournalMedia] {
        lock.lock(); defer { lock.unlock() }
        return items.sorted { $0.date > $1.date }
    }

    public func fileURL(for item: JournalMedia) throws -> URL {
        lock.lock(); defer { lock.unlock() }
        guard Self.isSafe(item.relativeFilename) else { throw StoreError.invalidRelativeFilename }
        let url = directoryURL.appendingPathComponent(item.relativeFilename)
        guard fileManager.fileExists(atPath: url.path) else { throw StoreError.mediaNotFound }
        return url
    }

    @discardableResult
    public func importMedia(from sourceURL: URL, id: UUID = UUID(), type: JournalMediaType, date: Date = Date(), duration: TimeInterval, journeyID: UUID? = nil, coordinate: GeoPoint? = nil, isImported: Bool = false, capturedOnWatch: Bool = false) throws -> JournalMedia {
        lock.lock(); defer { lock.unlock() }
        guard duration.isFinite, duration > 0 else { throw StoreError.invalidDuration }
        guard fileManager.fileExists(atPath: sourceURL.path) else { throw StoreError.sourceFileMissing }
        if let existing = items.first(where: { $0.id == id }) { return existing }
        let ext = sourceURL.pathExtension.isEmpty ? (type == .audio ? "m4a" : "mov") : sourceURL.pathExtension
        let filename = UUID().uuidString + "." + ext
        guard Self.isSafe(filename) else { throw StoreError.invalidRelativeFilename }
        let destination = directoryURL.appendingPathComponent(filename)
        try fileManager.copyItem(at: sourceURL, to: destination)
        let item = JournalMedia(id: id, type: type, date: date, duration: duration, relativeFilename: filename, journeyID: journeyID, coordinate: coordinate, isImported: isImported, capturedOnWatch: capturedOnWatch)
        do { try persist(items + [item]) }
        catch { try? fileManager.removeItem(at: destination); throw error }
        items.append(item)
        return item
    }

    public func delete(_ item: JournalMedia) throws {
        lock.lock(); defer { lock.unlock() }
        guard let stored = items.first(where: { $0.id == item.id }) else { throw StoreError.mediaNotFound }
        guard Self.isSafe(stored.relativeFilename) else { throw StoreError.invalidRelativeFilename }
        let original = directoryURL.appendingPathComponent(stored.relativeFilename)
        let tombstone = original.appendingPathExtension("pending-delete")
        let hadFile = fileManager.fileExists(atPath: original.path)
        if hadFile { try fileManager.moveItem(at: original, to: tombstone) }
        let updated = items.filter { $0.id != item.id }
        do { try persist(updated) }
        catch {
            if hadFile { try? fileManager.moveItem(at: tombstone, to: original) }
            throw error
        }
        // Keep in-memory state aligned with the committed index, even if disk cleanup reports an error.
        items = updated
        if hadFile { try fileManager.removeItem(at: tombstone) }
    }

    private func persist(_ updated: [JournalMedia]) throws {
        try JSONEncoder().encode(updated).write(to: indexURL, options: .atomic)
    }
    private static func isSafe(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.contains("..")
    }
}
