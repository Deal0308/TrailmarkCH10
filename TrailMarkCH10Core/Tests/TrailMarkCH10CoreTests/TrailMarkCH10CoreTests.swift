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
        #expect(summary.hydrationMilliliters == 0)
        #expect(summary.hasActivityData == false)
    }

    @Test
    func defaultActivitySummaryContainsZeroValues() {
        let summary = ActivitySummary()

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
        #expect(abs(summary.distanceMiles - 3.694493103090629) < 0.00001)
        #expect(summary.activeEnergyKilocalories == 542.3)
        #expect(summary.date == date)
        #expect(summary.hasActivityData)
    }

    @Test
    func hasActivityDataIsTrueWhenActivityExists() {
        #expect(ActivitySummary(steps: 1).hasActivityData)
        #expect(ActivitySummary(distanceMeters: 1).hasActivityData)
        #expect(ActivitySummary(activeEnergyKilocalories: 1).hasActivityData)
    }

    @Test
    func distanceMetersConvertToMiles() {
        let summary = ActivitySummary(distanceMeters: 1609.344)

        #expect(abs(summary.distanceMiles - 1) < 0.000001)
    }

    @Test
    func distanceTextShowsOneDecimalPlaceAndUnit() {
        let summary = ActivitySummary(distanceMeters: 1609.344)

        #expect(summary.distanceText == "1.0 mi")
    }

    @Test
    func activeEnergyTextRoundsToWholeKilocalories() {
        let summary = ActivitySummary(activeEnergyKilocalories: 541.728)

        #expect(summary.activeEnergyText == "542 kcal")
    }

    @Test
    func stepsTextUsesLocalizedNumberFormatting() {
        let summary = ActivitySummary(steps: 8425)

        #expect(summary.stepsText == 8425.formatted(.number))
    }

    @Test
    func hydrationOnlySummaryIsNotEmpty() {
        let summary = ActivitySummary(hydrationMilliliters: 250)

        #expect(summary.hasActivityData)
        #expect(ActivitySummary().hydrationMilliliters == 0)
    }

    @Test
    func hydrationTextRoundsToWholeMilliliters() {
        let summary = ActivitySummary(hydrationMilliliters: 1250.7)
        let expectedValue = 1251.formatted(.number.precision(.fractionLength(0)))

        #expect(summary.hydrationText == "\(expectedValue) mL")
        #expect(ActivitySummary.empty.hydrationText == "0 mL")
    }

    @Test
    func hydrationSurvivesEncodingAndDecoding() throws {
        let summary = ActivitySummary(hydrationMilliliters: 750.5)
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(ActivitySummary.self, from: data)

        #expect(decoded == summary)
        #expect(decoded.hydrationMilliliters == 750.5)
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

    @Test
    func mediaStorePersistsRelativeMediaAndDeletesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("recording.m4a")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("memo".utf8).write(to: source)

        let store = try JournalMediaStore(directoryURL: directory)
        let item = try store.importMedia(from: source, type: .audio, duration: 12.4)

        #expect(!item.relativeFilename.hasPrefix("/"))
        #expect(!item.relativeFilename.contains(".."))
        #expect(item.type == .audio)
        #expect(item.durationText == "0:12")
        let storedURL = try store.fileURL(for: item)
        #expect(FileManager.default.fileExists(atPath: storedURL.path))

        try store.delete(item)
        #expect(store.media.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: storedURL.path))

        let secondSource = directory.appendingPathComponent("second.m4a")
        try Data("memo 2".utf8).write(to: secondSource)
        let second = try store.importMedia(from: secondSource, type: .audio, duration: 1)
        let secondURL = try store.fileURL(for: second)
        try FileManager.default.removeItem(at: secondURL)
        try store.delete(second)
        #expect(store.media.isEmpty)
    }

    @Test
    func recoveryWindowsBracketLastNightAndSevenEnergyDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 11,
            hour: 9,
            minute: 30
        ).date)

        let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)
        let expectedSleepStart = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 10,
            hour: 18
        ).date)

        #expect(windows.sleepStart == expectedSleepStart)
        #expect(windows.sleepEnd == now)
        let expectedEnergyStart = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 5
        ).date)
        #expect(windows.energyStart == expectedEnergyStart)
        #expect(windows.energyEnd == now)
    }

    @Test
    func recoverySummaryFormatsSleepAndEnergy() {
        let start = Date(timeIntervalSince1970: 1_000)
        let summary = RecoverySummary(
            sleepDuration: 7 * 60 * 60 + 30 * 60,
            sleepWindowStart: start,
            sleepWindowEnd: start.addingTimeInterval(60),
            dailyEnergy: [DailyEnergy(date: start, kilocalories: 542.4)],
            date: start
        )

        #expect(summary.sleepDurationText == "7h 30m")
        #expect(summary.hasSleepData)
        #expect(summary.hasEnergyData)
        #expect(summary.dailyEnergy[0].kilocaloriesText == "542")
    }
}
