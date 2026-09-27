import Foundation

/// Evidence returned by HealthKit's successful finish operation, not a claim that
/// the person has checked the workout in the Health app. A locked watch can save
/// successfully without returning the workout object or its UUID.
public struct WorkoutSaveReceipt: Codable, Equatable, Sendable {
    public let workoutID: UUID?
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let savedAt: Date

    public init(workoutID: UUID?, startDate: Date, endDate: Date, duration: TimeInterval, savedAt: Date = Date()) {
        self.workoutID = workoutID
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.savedAt = savedAt
    }

    public var dateText: String { startDate.formatted(date: .abbreviated, time: .shortened) }
    public var durationText: String {
        let seconds = Int(min(duration, Double(Int.max / 2)))
        return seconds >= 3600
            ? String(format: "%dh %02dm %02ds", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%dm %02ds", seconds / 60, seconds % 60)
    }
    public var confirmationText: String {
        workoutID == nil
            ? "Your walk was saved. Unlock your watch, then check Apple Health for its details."
            : "Your walking workout was saved to Apple Health."
    }
}
