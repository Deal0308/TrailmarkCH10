import Foundation
import HealthKit

/// One reusable HealthKit service for Today and a journey's own time interval.
@MainActor
public final class ActivityHealthService: ActivityHealthProviding {
    let store: HKHealthStore?
    private let scope: ActivityHealthScope

    #if os(watchOS)
    public var onLiveVitals: ((LiveVitalsSnapshot) -> Void)?
    public var onLiveVitalsError: ((String) -> Void)?
    var liveVitalsQueries: [HKQuery] = []
    var liveVitalsSnapshot: LiveVitalsSnapshot = .empty
    var liveVitalsDayStart: Date?
    var liveVitalsRolloverTask: Task<Void, Never>?
    var isLiveVitalsStreaming = false
    var liveVitalsQueryGeneration = 0
    var liveVitalsStartGeneration = 0
    #endif

    public init(scope: ActivityHealthScope = .allMetrics) {
        self.scope = scope
        store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    public func readActivity(from start: Date, to end: Date) async throws -> JourneyHealthSummary {
        guard let store else { throw ActivityHealthError.unavailable }
        let types: Set<HKObjectType>
        switch scope {
        case .stepsOnly:
            types = [HKQuantityType(.stepCount)]
        case .allMetrics:
            types = [HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned), HKQuantityType(.dietaryWater)]
        }
        try await store.requestAuthorization(toShare: [], read: types)
        guard end > start else {
            return JourneyHealthSummary(steps: nil, distanceMeters: nil, activeEnergyKilocalories: nil, hydrationMilliliters: nil)
        }
        if case .stepsOnly = scope {
            let steps = try await sum(.stepCount, unit: .count(), start: start, end: end, store: store)
            return JourneyHealthSummary(steps: steps, distanceMeters: nil, activeEnergyKilocalories: nil, hydrationMilliliters: nil)
        }
        async let steps = sum(.stepCount, unit: .count(), start: start, end: end, store: store)
        async let distance = sum(.distanceWalkingRunning, unit: .meter(), start: start, end: end, store: store)
        async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end, store: store)
        async let water = sum(.dietaryWater, unit: .literUnit(with: .milli), start: start, end: end, store: store)
        return try await JourneyHealthSummary(steps: steps, distanceMeters: distance, activeEnergyKilocalories: energy, hydrationMilliliters: water)
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date, store: HKHealthStore) async throws -> Double? {
        // Only include samples fully inside the interval. In particular, a journey must
        // not claim an entire quantity whose sample spans well outside its start/end.
        // This conservative policy may omit boundary-spanning samples (documented in the report).
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error, (error as? HKError)?.code != .errorNoData { continuation.resume(throwing: error) }
                else { continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }
}

private enum ActivityHealthError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Health data is unavailable on this device." }
}
