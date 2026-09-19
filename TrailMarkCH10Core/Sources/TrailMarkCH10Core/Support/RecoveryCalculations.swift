import Foundation

public enum SleepDurationCalculator {
    /// Counts the union of asleep intervals inside the requested window, in elapsed seconds.
    /// Clipping includes the portion of a sample crossing a window boundary. Merging avoids
    /// counting duplicate or overlapping samples (for example, from a watch and another app)
    /// more than once, while preserving gaps when no source reports sleep.
    public static func duration(intervals: [SleepInterval], window: DateInterval) -> TimeInterval {
        let clipped = intervals.compactMap { interval -> SleepInterval? in
            let start = max(interval.start, window.start)
            let end = min(interval.end, window.end)
            guard start < end else { return nil }
            return SleepInterval(start: start, end: end)
        }.sorted { $0.start < $1.start }

        guard var current = clipped.first else { return 0 }
        var total: TimeInterval = 0
        for interval in clipped.dropFirst() {
            if interval.start <= current.end {
                current = SleepInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.end.timeIntervalSince(current.start)
                current = interval
            }
        }
        return total + current.end.timeIntervalSince(current.start)
    }
}
