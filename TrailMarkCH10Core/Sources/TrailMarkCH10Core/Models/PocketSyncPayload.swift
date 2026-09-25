import Foundation

/// A completed watch workout represented without HealthKit or WatchConnectivity types.
/// Its identifier is also used as the iPhone Journey identifier so later memo
/// transfers can attach to the same activity even when payloads arrive out of order.
public struct WatchActivityRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let averageHeartRateBPM: Double?
    public let activeEnergyKilocalories: Double?

    public init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        averageHeartRateBPM: Double?,
        activeEnergyKilocalories: Double?
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = max(endDate, startDate)
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.averageHeartRateBPM = Self.positive(averageHeartRateBPM)
        self.activeEnergyKilocalories = Self.nonnegative(activeEnergyKilocalories)
    }

    public var durationText: String {
        let seconds = Int(min(duration.rounded(), Double(Int.max / 2)))
        if seconds < 3600 { return String(format: "%dm %02ds", seconds / 60, seconds % 60) }
        return String(format: "%dh %02dm", seconds / 3600, (seconds % 3600) / 60)
    }

    private static func positive(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    private static func nonnegative(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}

/// Replaceable, lightweight state sent with `applicationContext`.
public struct PocketSyncSummary: Codable, Equatable, Sendable {
    public let activityID: UUID
    public let activityDate: Date
    public let duration: TimeInterval
    public let updatedAt: Date

    public init(activityID: UUID, activityDate: Date, duration: TimeInterval, updatedAt: Date = Date()) {
        self.activityID = activityID
        self.activityDate = activityDate
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.updatedAt = updatedAt
    }

    public var durationText: String {
        let seconds = Int(min(max(0, duration.isFinite ? duration : 0).rounded(), Double(Int.max / 2)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Metadata accompanying a voice-memo file transfer. The audio bytes travel as
/// a file; only this small, property-list-safe envelope is encoded in metadata.
public struct PocketMemoMetadata: Codable, Equatable, Sendable {
    public let mediaID: UUID
    public let date: Date
    public let duration: TimeInterval
    public let journeyID: UUID?

    public init(mediaID: UUID, date: Date, duration: TimeInterval, journeyID: UUID?) {
        self.mediaID = mediaID
        self.date = date
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.journeyID = journeyID
    }
}

/// A received watch memo staged in package-owned Application Support until the
/// iPhone media store has copied and indexed it.
public struct IncomingPocketMemo: Sendable {
    public let metadata: PocketMemoMetadata
    public let stagedFileURL: URL

    public init(metadata: PocketMemoMetadata, stagedFileURL: URL) {
        self.metadata = metadata
        self.stagedFileURL = stagedFileURL
    }
}
