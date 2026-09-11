import Foundation
import Combine

/// A simple value type that represents one day's activity totals.
public struct ActivitySummary: Equatable, Sendable {
    /// Total step count returned from HealthKit for the selected date range.
    public let steps: Int

    /// Walking and running distance in meters; the app converts this to miles for display.
    public let distanceMeters: Double

    /// Active energy burned in kilocalories for the selected date range.
    public let activeEnergyKilocalories: Double

    /// Timestamp for when this summary was measured or generated.
    public let date: Date

    /// Creates a summary from already-calculated HealthKit totals.
    ///
    /// The default `date` keeps existing call sites simple while still allowing tests and HealthKit refreshes to provide an exact timestamp.
    public init(
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        date: Date = Date()
    ) {
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.date = date
    }

    /// A zero-value summary used before HealthKit data loads or when data is unavailable.
    public static let empty = ActivitySummary(
        steps: 0,
        distanceMeters: 0,
        activeEnergyKilocalories: 0
    )

    /// `true` when at least one tracked activity metric has a non-zero value.
    public var hasActivityData: Bool {
        steps > 0 || distanceMeters > 0 || activeEnergyKilocalories > 0
    }
}
