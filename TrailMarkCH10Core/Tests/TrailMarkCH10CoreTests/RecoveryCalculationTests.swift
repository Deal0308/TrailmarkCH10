import Foundation
import Testing
@testable import TrailMarkCH10Core

struct RecoveryCalculationTests {
    private func chicagoCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        return calendar
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: year, month: month, day: day,
            hour: hour, minute: minute
        )))
    }

    @Test
    func sleepWindowUsesCurrentTimeBeforeNoonAndNoonAfterward() throws {
        let calendar = try chicagoCalendar()
        let morning = try date(2026, 9, 12, 8, 30, calendar: calendar)
        let afternoon = try date(2026, 9, 12, 16, calendar: calendar)
        let previousEvening = try date(2026, 9, 11, 18, calendar: calendar)
        let noon = try date(2026, 9, 12, 12, calendar: calendar)
        let morningWindows = RecoveryDateWindowProvider.windows(now: morning, calendar: calendar)
        let afternoonWindows = RecoveryDateWindowProvider.windows(now: afternoon, calendar: calendar)

        #expect(morningWindows.sleepStart == previousEvening)
        #expect(morningWindows.sleepEnd == morning)
        #expect(afternoonWindows.sleepStart == previousEvening)
        #expect(afternoonWindows.sleepEnd == noon)
        #expect(afternoonWindows.energyEnd == afternoon)
    }

    @Test
    func midnightStartsANewEnergyDayAndKeepsThePriorEveningSleepWindow() throws {
        let calendar = try chicagoCalendar()
        let now = try date(2026, 9, 12, calendar: calendar)
        let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)
        let days = RecoveryDateWindowProvider.energyDays(now: now, calendar: calendar)

        #expect(windows.sleepStart == (try date(2026, 9, 11, 18, calendar: calendar)))
        #expect(windows.sleepEnd == now)
        #expect(windows.energyEnd == now)
        #expect(days.count == 7)
        #expect(days.last == now)
        #expect(days.first == windows.energyStart)
    }

    @Test
    func springForwardUsesLocalWallTimesAndSeventeenElapsedHours() throws {
        let calendar = try chicagoCalendar()
        let now = try date(2026, 3, 8, 16, calendar: calendar)
        let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)

        #expect(windows.sleepStart == (try date(2026, 3, 7, 18, calendar: calendar)))
        #expect(windows.sleepEnd == (try date(2026, 3, 8, 12, calendar: calendar)))
        #expect(windows.sleepEnd.timeIntervalSince(windows.sleepStart) == 17 * 3_600)

        // On the next day, yesterday itself contains the clock change. Its 6 p.m. must stay 6 p.m.
        let followingDay = RecoveryDateWindowProvider.windows(
            now: try date(2026, 3, 9, 9, calendar: calendar), calendar: calendar
        )
        #expect(followingDay.sleepStart == (try date(2026, 3, 8, 18, calendar: calendar)))
    }

    @Test
    func fallBackUsesLocalWallTimesAndNineteenElapsedHours() throws {
        let calendar = try chicagoCalendar()
        let now = try date(2026, 11, 1, 16, calendar: calendar)
        let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)

        #expect(windows.sleepStart == (try date(2026, 10, 31, 18, calendar: calendar)))
        #expect(windows.sleepEnd == (try date(2026, 11, 1, 12, calendar: calendar)))
        #expect(windows.sleepEnd.timeIntervalSince(windows.sleepStart) == 19 * 3_600)

        let followingDay = RecoveryDateWindowProvider.windows(
            now: try date(2026, 11, 2, 9, calendar: calendar), calendar: calendar
        )
        #expect(followingDay.sleepStart == (try date(2026, 11, 1, 18, calendar: calendar)))
    }

    @Test
    func energyDaysCrossYearBoundaryWithSevenCalendarDates() throws {
        let calendar = try chicagoCalendar()
        let now = try date(2027, 1, 3, 14, calendar: calendar)
        let expected = try [
            date(2026, 12, 28, calendar: calendar), date(2026, 12, 29, calendar: calendar),
            date(2026, 12, 30, calendar: calendar), date(2026, 12, 31, calendar: calendar),
            date(2027, 1, 1, calendar: calendar), date(2027, 1, 2, calendar: calendar),
            date(2027, 1, 3, calendar: calendar)
        ]
        let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)

        #expect(RecoveryDateWindowProvider.energyDays(now: now, calendar: calendar) == expected)
        #expect(windows.energyStart == expected.first)
        #expect(windows.energyEnd == now)
    }

    @Test
    func energyDaysFollowCalendarRatherThanFixedTwentyFourHourSteps() throws {
        let calendar = try chicagoCalendar()
        for (month, day, expectedHours) in [(3, 9, 23.0), (11, 2, 25.0)] {
            let now = try date(2026, month, day, 14, calendar: calendar)
            let days = RecoveryDateWindowProvider.energyDays(now: now, calendar: calendar)

            #expect(days.count == 7)
            #expect(Set(days).count == 7)
            #expect(days == days.sorted())
            #expect(days.allSatisfy { $0 == calendar.startOfDay(for: $0) })
            #expect(days[6].timeIntervalSince(days[5]) == expectedHours * 3_600)
        }
    }

    @Test
    func sleepUnionAvoidsDoubleCountingAndPreservesAwakeGaps() {
        let base = Date(timeIntervalSince1970: 0)
        func interval(_ start: Double, _ end: Double) -> SleepInterval {
            SleepInterval(start: base.addingTimeInterval(start), end: base.addingTimeInterval(end))
        }
        let window = DateInterval(start: base, duration: 100)
        // The union is [0, 50] plus [70, 100]. The twenty-second gap remains excluded.
        let intervals = [
            interval(70, 90), interval(10, 30), interval(-20, 20), interval(20, 40),
            interval(10, 30), interval(15, 18), interval(40, 50), interval(80, 120)
        ]

        #expect(SleepDurationCalculator.duration(intervals: intervals, window: window) == 80)
    }

    @Test
    func sleepIgnoresOutOfWindowEmptyAndReversedIntervals() {
        let base = Date(timeIntervalSince1970: 0)
        let window = DateInterval(start: base, duration: 100)
        let intervals = [
            SleepInterval(start: base.addingTimeInterval(-30), end: base),
            SleepInterval(start: window.end, end: window.end.addingTimeInterval(30)),
            SleepInterval(start: base.addingTimeInterval(10), end: base.addingTimeInterval(10)),
            SleepInterval(start: base.addingTimeInterval(30), end: base.addingTimeInterval(20))
        ]

        #expect(SleepDurationCalculator.duration(intervals: [], window: window) == 0)
        #expect(SleepDurationCalculator.duration(intervals: intervals, window: window) == 0)
        #expect(SleepDurationCalculator.duration(
            intervals: [SleepInterval(start: base.addingTimeInterval(-10), end: window.end.addingTimeInterval(10))],
            window: window
        ) == 100)
    }

    @Test
    func sleepDurationUsesActualElapsedTimeAcrossBothClockChanges() throws {
        let calendar = try chicagoCalendar()
        for (month, day, expectedHours) in [(3, 8, 7.0), (11, 1, 9.0)] {
            let now = try date(2026, month, day, 10, calendar: calendar)
            let windows = RecoveryDateWindowProvider.windows(now: now, calendar: calendar)
            let end = try date(2026, month, day, 7, calendar: calendar)
            let priorDay = try #require(calendar.date(byAdding: .day, value: -1, to: now))
            let start = try #require(calendar.date(bySettingHour: 23, minute: 0, second: 0, of: priorDay))

            #expect(SleepDurationCalculator.duration(
                intervals: [SleepInterval(start: start, end: end)],
                window: DateInterval(start: windows.sleepStart, end: windows.sleepEnd)
            ) == expectedHours * 3_600)
        }
    }

    @Test
    func missingEnergyAndMeasuredZeroRemainDistinctThroughPersistence() throws {
        let date = Date(timeIntervalSince1970: 0)
        let missing = DailyEnergy(date: date, kilocalories: 0, hasSamples: false)
        let measuredZero = DailyEnergy(date: date, kilocalories: 0)
        let encoded = try JSONEncoder().encode([missing, measuredZero])
        let decoded = try JSONDecoder().decode([DailyEnergy].self, from: encoded)

        #expect(decoded == [missing, measuredZero])
        #expect(!RecoverySummary(dailyEnergy: [missing]).hasEnergyData)
        #expect(RecoverySummary(dailyEnergy: [measuredZero]).hasEnergyData)
        #expect(!RecoverySummary.empty.hasEnergyData)

        let legacyJSON = Data(#"{"date":0,"kilocalories":12}"#.utf8)
        #expect(try JSONDecoder().decode(DailyEnergy.self, from: legacyJSON).hasSamples)
    }
}
