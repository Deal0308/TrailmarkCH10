import Testing
import Foundation
@testable import TrailMarkCH10Core

/// Unit tests for the reusable core package.
struct TrailMarkCH10CoreTests {
    @Test
    func packageLoads() {
        // Verifies the package module can be imported and read by tests.
        #expect(TrailMarkCH10Core.name == "TrailMarkCH10Core")
    }

    @Test
    func emptyActivitySummaryContainsZeroValues() {
        let summary = ActivitySummary.empty

        // The empty summary is what the app shows before real HealthKit data is available.
        #expect(summary.steps == 0)
        #expect(summary.distanceMeters == 0)
        #expect(summary.activeEnergyKilocalories == 0)
        #expect(summary.hasActivityData == false)
    }

    @Test
    func activitySummaryStoresInitializedValues() throws {
        let date = try #require(DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: 2026,
            month: 9,
            day: 5,
            hour: 14,
            minute: 30
        ).date)

        let summary = ActivitySummary(
            steps: 8425,
            distanceMeters: 5945.7,
            activeEnergyKilocalories: 542.3,
            date: date
        )

        // Confirms the initializer stores each value exactly as supplied.
        #expect(summary.steps == 8425)
        #expect(summary.distanceMeters == 5945.7)
        #expect(summary.activeEnergyKilocalories == 542.3)
        #expect(summary.date == date)
        #expect(summary.hasActivityData)
    }

    @Test
    func todayDateRangeStartsAtStartOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        let now = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 5,
            hour: 14,
            minute: 30
        ).date)

        let expectedStart = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 5
        ).date)

        let range = TodayDateRangeProvider.range(now: now, calendar: calendar)

        // HealthKit queries need a start-of-day lower bound and a current-time upper bound.
        #expect(range.startDate == expectedStart)
        #expect(range.endDate == now)
    }
}
