import Foundation

/// Start and end dates used when querying data for the current day.
public struct TodayDateRange: Equatable, Sendable {
    /// Midnight at the beginning of the requested day.
    public let startDate: Date

    /// Usually the current moment, used as the upper bound for today's query.
    public let endDate: Date

    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// Builds date ranges for HealthKit queries.
public enum TodayDateRangeProvider {
    /// Returns a range from the start of the current day through `now`.
    public static func range(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayDateRange {
        TodayDateRange(
            startDate: calendar.startOfDay(for: now),
            endDate: now
        )
    }
}
