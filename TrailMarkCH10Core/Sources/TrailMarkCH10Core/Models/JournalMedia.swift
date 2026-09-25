import Foundation

/// The capture formats supported by the field journal.
public enum JournalMediaType: String, Codable, CaseIterable, Sendable {
    case audio
    case video
}

/// Metadata for one voice or video memo. `relativeFilename` is always relative
/// to the media store directory and is never an absolute URL.
public struct JournalMedia: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: JournalMediaType
    public let date: Date
    public let duration: TimeInterval
    public let relativeFilename: String
    public let isImported: Bool?
    public let journeyID: UUID?
    public let coordinate: GeoPoint?
    public let capturedOnWatch: Bool?

    public init(
        id: UUID = UUID(),
        type: JournalMediaType,
        date: Date = Date(),
        duration: TimeInterval,
        relativeFilename: String,
        journeyID: UUID? = nil,
        coordinate: GeoPoint? = nil,
        isImported: Bool = false,
        capturedOnWatch: Bool = false
    ) {
        self.id = id
        self.type = type
        self.date = date
        self.duration = duration
        self.relativeFilename = relativeFilename
        self.journeyID = journeyID
        self.coordinate = coordinate
        self.isImported = isImported
        self.capturedOnWatch = capturedOnWatch
    }

    public var isWatchMemo: Bool { capturedOnWatch == true || (isImported == true && type == .audio) }

    public var durationText: String {
        guard duration.isFinite, duration >= 0 else { return "Unavailable" }
        let totalSeconds = Int(min(duration.rounded(), Double(Int.max / 2)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
