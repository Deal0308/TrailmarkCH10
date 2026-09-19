import Foundation

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
