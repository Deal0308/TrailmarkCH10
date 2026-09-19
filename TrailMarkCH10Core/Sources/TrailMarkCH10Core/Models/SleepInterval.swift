import Foundation

/// An interval classified as asleep by the data source. In-bed and awake samples must be excluded.
public struct SleepInterval: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}
