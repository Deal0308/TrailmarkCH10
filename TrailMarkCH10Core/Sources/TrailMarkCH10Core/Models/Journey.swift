import Foundation

public struct GeoPoint: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    public let horizontalAccuracy: Double
    public let segment: Int

    public init(latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double, segment: Int = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.segment = segment
    }
}

public struct JourneyHealthSummary: Codable, Equatable, Sendable {
    public let steps: Double?
    public let distanceMeters: Double?
    public let activeEnergyKilocalories: Double?
    public let hydrationMilliliters: Double?
    public let queriedAt: Date

    public init(steps: Double?, distanceMeters: Double?, activeEnergyKilocalories: Double?, hydrationMilliliters: Double?, queriedAt: Date = Date()) {
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.hydrationMilliliters = hydrationMilliliters
        self.queriedAt = queriedAt
    }
}

public enum JourneyStatus: String, Codable, Sendable {
    case recording, completed, interrupted
}

public struct Journey: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let startDate: Date
    public var endDate: Date?
    public var status: JourneyStatus
    public var points: [GeoPoint]
    public var distanceMeters: Double
    public var health: JourneyHealthSummary?
    /// Present when this journey was created from a completed Apple Watch workout.
    public var watchActivity: WatchActivityRecord?

    public init(id: UUID = UUID(), title: String, startDate: Date = Date()) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = nil
        self.status = .recording
        self.points = []
        self.distanceMeters = 0
        self.health = nil
        self.watchActivity = nil
    }

    public var duration: TimeInterval { max(0, (endDate ?? Date()).timeIntervalSince(startDate)) }
    public var durationText: String {
        let seconds = Int(duration)
        return String(format: "%dh %02dm", seconds / 3600, (seconds % 3600) / 60)
    }
    public var distanceText: String { "\((distanceMeters / 1000).formatted(.number.precision(.fractionLength(2)))) km" }
}

/// The identity and GPS fix at recording start; never inferred later from a different journey.
public struct MemoCaptureContext: Sendable {
    public let date: Date
    public let journeyID: UUID?
    public let coordinate: GeoPoint?

    public init(date: Date = Date(), journeyID: UUID? = nil, coordinate: GeoPoint? = nil) {
        self.date = date
        self.journeyID = journeyID
        self.coordinate = coordinate
    }
}
