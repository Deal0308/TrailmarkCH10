import Foundation

/// Lifecycle shared by the iPhone workout tab and Apple Watch workout screen.
public enum WorkoutTrackingState: String, Codable, Sendable {
    case idle
    case requestingAuthorization
    case starting
    case running
    case paused
    case ending
    case completed
    case failed
}

/// Framework-independent workout values. Apple Watch produces these values and
/// the companion iPhone renders the same model when the session is mirrored.
public struct WorkoutMetrics: Codable, Equatable, Sendable {
    public let state: WorkoutTrackingState
    public let startedAt: Date?
    public let elapsedTime: TimeInterval
    public let currentHeartRateBPM: Double?
    public let heartRateSampleDate: Date?
    public let averageHeartRateBPM: Double?
    public let activeEnergyKilocalories: Double?
    public let statusMessage: String

    public init(
        state: WorkoutTrackingState = .idle,
        startedAt: Date? = nil,
        elapsedTime: TimeInterval = 0,
        currentHeartRateBPM: Double? = nil,
        heartRateSampleDate: Date? = nil,
        averageHeartRateBPM: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        statusMessage: String = "Ready to start a walking workout."
    ) {
        self.state = state
        self.startedAt = startedAt
        self.elapsedTime = elapsedTime.isFinite ? max(0, elapsedTime) : 0
        self.currentHeartRateBPM = Self.validHeartRate(currentHeartRateBPM)
        self.heartRateSampleDate = self.currentHeartRateBPM == nil ? nil : heartRateSampleDate
        self.averageHeartRateBPM = Self.validHeartRate(averageHeartRateBPM)
        self.activeEnergyKilocalories = activeEnergyKilocalories.flatMap {
            $0.isFinite && $0 >= 0 ? $0 : nil
        }
        self.statusMessage = statusMessage
    }

    public static let idle = WorkoutMetrics()

    public var isActive: Bool {
        state == .starting || state == .running || state == .paused || state == .ending
    }

    public var currentHeartRateText: String {
        currentHeartRateBPM.map { "\($0.formatted(.number.precision(.fractionLength(0)))) BPM" } ?? "— BPM"
    }

    public var averageHeartRateText: String {
        averageHeartRateBPM.map { "\($0.formatted(.number.precision(.fractionLength(0)))) BPM" } ?? "— BPM"
    }

    public var energyText: String {
        activeEnergyKilocalories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "— kcal"
    }

    public var elapsedText: String {
        let seconds = Int(min(elapsedTime, Double(Int.max / 2)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func validHeartRate(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }
}
