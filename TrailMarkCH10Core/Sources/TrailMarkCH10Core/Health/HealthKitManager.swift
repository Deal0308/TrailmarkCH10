import Foundation
import HealthKit
import Observation

/// Loads today's activity metrics from HealthKit and exposes them to SwiftUI.
///
/// `@MainActor` keeps observable state changes on the main thread, which is what SwiftUI expects.
@MainActor
@Observable
public final class HealthKitManager {
    /// The latest activity totals shown by the dashboard.
    public private(set) var activitySummary: ActivitySummary

    /// Tracks whether a HealthKit refresh is currently running.
    public private(set) var isLoading: Bool

    /// User-facing explanation when HealthKit authorization or queries fail.
    public private(set) var errorMessage: String?

    /// Prevents the initial loading state from appearing after the first load attempt completes.
    public private(set) var hasCompletedInitialLoad: Bool

    /// HealthKit objects are not observable UI state, so Observation should ignore them.
    @ObservationIgnored private let healthStore: HKHealthStore?
    @ObservationIgnored private var hasRequestedAuthorization: Bool

    public init() {
        self.activitySummary = .empty
        self.isLoading = false
        self.errorMessage = nil
        self.hasCompletedInitialLoad = false
        self.healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
        self.hasRequestedAuthorization = false
    }

    /// Requests HealthKit access once, then loads today's totals.
    public func loadInitialData() async {
        guard !hasCompletedInitialLoad else { return }
        await requestAuthorizationIfNeeded()
        await refreshToday()
    }

    /// Refreshes steps, distance, and active energy for today.
    public func refreshToday() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasCompletedInitialLoad = true
        }

        guard healthStore != nil else {
            activitySummary = .empty
            errorMessage = "Health data is not available on this device."
            return
        }

        let dateRange = TodayDateRangeProvider.range()

        do {
            // Run the three HealthKit statistics queries concurrently so the dashboard refresh finishes faster.
            async let steps = sumQuantity(
                identifier: .stepCount,
                unit: .count(),
                startDate: dateRange.startDate,
                endDate: dateRange.endDate
            )
            async let distance = sumQuantity(
                identifier: .distanceWalkingRunning,
                unit: .meter(),
                startDate: dateRange.startDate,
                endDate: dateRange.endDate
            )
            async let activeEnergy = sumQuantity(
                identifier: .activeEnergyBurned,
                unit: .kilocalorie(),
                startDate: dateRange.startDate,
                endDate: dateRange.endDate
            )

            activitySummary = ActivitySummary(
                steps: Int((try await steps).rounded()),
                distanceMeters: try await distance,
                activeEnergyKilocalories: try await activeEnergy,
                date: dateRange.endDate
            )
        } catch {
            activitySummary = .empty
            errorMessage = "TrailMark could not load today's activity data."
            print("HealthKit query failed: \(error)")
        }
    }

    /// Used by the UI retry button after an error or empty-data state.
    public func retry() async {
        await requestAuthorizationIfNeeded()
        await refreshToday()
    }

    /// Asks the user for read access to the HealthKit quantity types the app needs.
    private func requestAuthorizationIfNeeded() async {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true

        guard let healthStore else {
            errorMessage = "Health data is not available on this device."
            hasCompletedInitialLoad = true
            return
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: healthReadTypes
            )
        } catch {
            errorMessage = "TrailMark could not request Health access."
            print("HealthKit authorization failed: \(error)")
        }
    }

    /// HealthKit quantity types this app reads from Apple Health.
    private var healthReadTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ])
    }

    /// Converts an `HKStatisticsQuery` callback into an async function that returns one summed value.
    private nonisolated func sumQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?
                    .sumQuantity()?
                    .doubleValue(for: unit) ?? 0

                continuation.resume(returning: value)
            }

            healthStore?.execute(query)
        }
    }
}
