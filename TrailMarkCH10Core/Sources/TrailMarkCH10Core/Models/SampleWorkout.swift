import Foundation

/// The sample is synthetic and is written only after the user taps Save.
public struct SampleWorkoutActivity: Equatable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let energyKilocalories: Double
    public let distanceMeters: Double
    public let averageHeartRateBPM: Double
    public var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    public init(id: UUID = UUID(), endingAt date: Date = Date()) {
        self.id = id
        self.startDate = date.addingTimeInterval(-20 * 60)
        self.endDate = date
        self.energyKilocalories = 120
        self.distanceMeters = 1_500
        self.averageHeartRateBPM = 128
    }
}

/// HealthKit's save result. This is not evidence of visual verification in Health.
public struct SampleWorkoutReceipt: Equatable, Sendable {
    /// HealthKit may successfully save while locked without returning the workout object.
    public let id: UUID?
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let energyKilocalories: Double
    public let distanceMeters: Double
    public let averageHeartRateBPM: Double

    public init(id: UUID?, activity: SampleWorkoutActivity) {
        self.id = id
        self.startDate = activity.startDate
        self.endDate = activity.endDate
        self.duration = activity.duration
        self.energyKilocalories = activity.energyKilocalories
        self.distanceMeters = activity.distanceMeters
        self.averageHeartRateBPM = activity.averageHeartRateBPM
    }
}
