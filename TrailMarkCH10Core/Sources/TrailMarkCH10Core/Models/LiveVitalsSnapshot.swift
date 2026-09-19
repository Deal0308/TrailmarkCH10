import Foundation

/// Framework-independent values rendered by the Apple Watch Live Vitals screen.
/// Optional values preserve the difference between a measured zero and a value
/// HealthKit did not make readable.
public struct LiveVitalsSnapshot: Equatable, Sendable {
    public let heartRateBPM: Double?
    public let stepsToday: Double?
    public let activeEnergyKilocaloriesToday: Double?
    public let heartRateSampleDate: Date?
    public let updatedAt: Date?

    public init(
        heartRateBPM: Double? = nil,
        stepsToday: Double? = nil,
        activeEnergyKilocaloriesToday: Double? = nil,
        heartRateSampleDate: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.heartRateBPM = Self.positive(heartRateBPM)
        self.stepsToday = Self.nonnegative(stepsToday)
        self.activeEnergyKilocaloriesToday = Self.nonnegative(activeEnergyKilocaloriesToday)
        self.heartRateSampleDate = self.heartRateBPM == nil ? nil : heartRateSampleDate
        self.updatedAt = updatedAt
    }

    public static let empty = LiveVitalsSnapshot()

    public var hasReadableData: Bool {
        heartRateBPM != nil || stepsToday != nil || activeEnergyKilocaloriesToday != nil
    }

    public var heartRateText: String {
        heartRateBPM?.formatted(.number.precision(.fractionLength(0))) ?? "—"
    }

    public var stepsText: String {
        stepsToday?.formatted(.number.precision(.fractionLength(0))) ?? "—"
    }

    public var activeEnergyText: String {
        activeEnergyKilocaloriesToday?
            .formatted(.number.precision(.fractionLength(0))) ?? "—"
    }

    public var heartRateSampleText: String {
        guard let heartRateSampleDate else { return "Waiting for a heart-rate sample" }
        return "Measured \(heartRateSampleDate.formatted(date: .omitted, time: .shortened))"
    }

    public var updateText: String {
        guard let updatedAt else { return "Waiting for Health data" }
        return "Updated \(updatedAt.formatted(date: .omitted, time: .shortened))"
    }

    public var heartRateAccessibilityValue: String {
        guard heartRateBPM != nil else { return "No readable heart-rate sample" }
        return "\(heartRateText) beats per minute. \(heartRateSampleText)"
    }

    public var stepsAccessibilityValue: String {
        guard stepsToday != nil else { return "Steps unavailable" }
        return "\(stepsText) steps today"
    }

    public var activeEnergyAccessibilityValue: String {
        guard activeEnergyKilocaloriesToday != nil else { return "Active energy unavailable" }
        return "\(activeEnergyText) kilocalories today"
    }

    private static func positive(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    private static func nonnegative(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}

public enum LiveVitalsPhase: Sendable {
    case idle
    case requestingAuthorization
    case streaming
    case failed
}
