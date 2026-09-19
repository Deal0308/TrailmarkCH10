import Foundation

/// One calendar day's cumulative active energy total.
public struct DailyEnergy: Identifiable, Codable, Equatable, Sendable {
    public let date: Date
    public let kilocalories: Double
    /// False when HealthKit returned no quantity for this day. A measured zero remains data.
    public let hasSamples: Bool

    public init(date: Date, kilocalories: Double, hasSamples: Bool = true) {
        self.date = date
        self.kilocalories = kilocalories
        self.hasSamples = hasSamples
    }

    private enum CodingKeys: String, CodingKey {
        case date, kilocalories, hasSamples
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        kilocalories = try container.decode(Double.self, forKey: .kilocalories)
        // Preserve compatibility with summaries encoded before availability was modeled.
        hasSamples = try container.decodeIfPresent(Bool.self, forKey: .hasSamples) ?? true
    }

    public var id: Date { date }
    public var kilocaloriesText: String {
        kilocalories.formatted(.number.precision(.fractionLength(0)))
    }
}

/// The recovery data shown by the Recovery screen.
public struct RecoverySummary: Codable, Equatable, Sendable {
    public let sleepDuration: TimeInterval
    public let sleepWindowStart: Date
    public let sleepWindowEnd: Date
    public let dailyEnergy: [DailyEnergy]
    public let date: Date

    public init(
        sleepDuration: TimeInterval = 0,
        sleepWindowStart: Date = Date.distantPast,
        sleepWindowEnd: Date = Date.distantPast,
        dailyEnergy: [DailyEnergy] = [],
        date: Date = Date()
    ) {
        self.sleepDuration = sleepDuration
        self.sleepWindowStart = sleepWindowStart
        self.sleepWindowEnd = sleepWindowEnd
        self.dailyEnergy = dailyEnergy
        self.date = date
    }

    public static let empty = RecoverySummary()

    public var sleepDurationText: String {
        let totalMinutes = max(0, Int((sleepDuration / 60).rounded()))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    public var hasSleepData: Bool { sleepDuration > 0 }
    public var hasEnergyData: Bool { dailyEnergy.contains { $0.hasSamples } }
}

/// Date windows used by the recovery queries.
public struct RecoveryDateWindows: Equatable, Sendable {
    public let sleepStart: Date
    public let sleepEnd: Date
    public let energyStart: Date
    public let energyEnd: Date
}
