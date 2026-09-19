import Foundation

/// A simple value type that represents one day's activity totals.
public struct ActivitySummary: Equatable, Sendable, Codable {
    /// Total step count returned from HealthKit for the selected date range.
    public let steps: Int

    /// Walking and running distance in meters, as returned from HealthKit.
    public let distanceMeters: Double

    /// Active energy burned in kilocalories for the selected date range.
    public let activeEnergyKilocalories: Double

    /// Water consumed in milliliters for the selected date range.
    public let hydrationMilliliters: Double

    /// Timestamp for when this summary was measured or generated.
    public let date: Date

    /// Creates a summary from already-calculated HealthKit totals.
    ///
    /// The default `date` keeps existing call sites simple while still allowing tests and HealthKit refreshes to provide an exact timestamp.
    public init(
        steps: Int = 0,
        distanceMeters: Double = 0,
        activeEnergyKilocalories: Double = 0,
        hydrationMilliliters: Double = 0,
        date: Date = Date()
    ) {
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.hydrationMilliliters = hydrationMilliliters
        self.date = date
    }

    /// A zero-value summary used before HealthKit data loads or when data is unavailable.
    public static let empty = ActivitySummary()

    /// `true` when at least one tracked activity metric has a non-zero value.
    public var hasActivityData: Bool {
        steps > 0 ||
        distanceMeters > 0 ||
        activeEnergyKilocalories > 0 ||
        hydrationMilliliters > 0
    }

    // MARK: - Display Helpers

    public var stepsText: String {
        steps.formatted(.number)
    }

    public var distanceMiles: Double {
        Measurement(
            value: distanceMeters,
            unit: UnitLength.meters
        )
        .converted(to: .miles)
        .value
    }

    public var distanceText: String {
        "\(distanceMiles.formatted(.number.precision(.fractionLength(1)))) mi"
    }

    public var activeEnergyText: String {
        "\(activeEnergyKilocalories.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    public var hydrationText: String {
        "\(hydrationMilliliters.formatted(.number.precision(.fractionLength(0)))) mL"
    }
}
