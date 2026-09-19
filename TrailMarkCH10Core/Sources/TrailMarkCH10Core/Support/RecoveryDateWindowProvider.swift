import Foundation

public enum RecoveryDateWindowProvider {
    /// Brackets last night's sleep from local 6 p.m. yesterday through local noon today.
    /// Before noon, the current time is the upper bound. Calendar wall times keep these boundaries
    /// stable through daylight-saving changes; adding 18 elapsed hours to midnight would not.
    public static func windows(now: Date = Date(), calendar: Calendar = .current) -> RecoveryDateWindows {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let sleepStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        let sleepEnd = min(now, noon)
        let energyStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return RecoveryDateWindows(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            energyStart: energyStart,
            energyEnd: now
        )
    }

    /// Seven local calendar-day starts in ascending order, including today (which is partial).
    public static func energyDays(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (-6...0).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.startOfDay(for: day)
        }
    }
}
