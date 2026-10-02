import Foundation

/// The view model depends on this service contract, not on HealthKit objects.
@MainActor
public protocol ActivityHealthProviding {
    func readActivity(from start: Date, to end: Date) async throws -> JourneyHealthSummary
}
