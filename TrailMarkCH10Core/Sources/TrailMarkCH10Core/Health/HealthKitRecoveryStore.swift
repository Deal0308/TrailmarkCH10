import Foundation
import HealthKit

/// All Recovery HealthKit reads, permissions, and workout writes live in this package.
@MainActor
public final class HealthKitRecoveryStore: RecoveryHealthProviding {
    private let healthStore: HKHealthStore?

    public init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    // Kept explicit and testable: permission to save a workout does not grant permission to save its quantities.
    static var readTypes: Set<HKObjectType> {
        [HKCategoryType(.sleepAnalysis), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate), HKObjectType.workoutType()]
    }

    static var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.heartRate)]
    }

    public func requestReadAuthorization() async throws {
        let store = try availableStore()
        // A successful request means the sheet completed, not that the person allowed every read.
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    public func readSleep(in window: DateInterval) async throws -> TimeInterval? {
        let store = try availableStore()
        // Default overlap semantics keep samples crossing 18:00 or the morning endpoint.
        // Strict start/end predicates would discard those samples before we could clip them.
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error, !Self.isNoData(error) {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: Self.sleepDuration(samples: samples as? [HKCategorySample] ?? [], window: window))
            }
            store.execute(query)
        }
    }

    /// In-bed and awake samples never count as sleep. Unioning asleep intervals also
    /// avoids counting the same minute twice when stages or tracking sources overlap.
    nonisolated static func sleepDuration(samples: [HKCategorySample], window: DateInterval) -> TimeInterval? {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let intervals = samples.filter {
            asleepValues.contains($0.value) && $0.startDate < window.end && $0.endDate > window.start
                && $0.endDate > $0.startDate
        }.map { SleepInterval(start: $0.startDate, end: $0.endDate) }
        guard !intervals.isEmpty else { return nil }
        return SleepDurationCalculator.duration(intervals: intervals, window: window)
    }

    public func readEnergy(windows: RecoveryDateWindows, calendar: Calendar) async throws -> [DailyEnergy] {
        let store = try availableStore()
        let days = RecoveryDateWindowProvider.energyDays(now: windows.energyEnd, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(
            withStart: windows.energyStart, end: windows.energyEnd, options: []
        )
        var interval = DateComponents(day: 1)
        interval.calendar = calendar
        interval.timeZone = calendar.timeZone

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.activeEnergyBurned),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: windows.energyStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { query, collection, error in
                defer { store.stop(query) }
                if let error, !Self.isNoData(error) {
                    continuation.resume(throwing: error)
                    return
                }
                let values = days.map { day in
                    collection?.statistics(for: day)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                }
                continuation.resume(returning: Self.energyBuckets(days: days, quantities: values))
            }
            store.execute(query)
        }
    }

    nonisolated static func energyBuckets(days: [Date], quantities: [Double?]) -> [DailyEnergy] {
        days.enumerated().map { index, day in
            let quantity = index < quantities.count ? quantities[index] : nil
            return DailyEnergy(date: day, kilocalories: quantity ?? 0, hasSamples: quantity != nil)
        }
    }

    public func saveSampleWorkout(_ activity: SampleWorkoutActivity) async throws -> SampleWorkoutReceipt {
        let store = try availableStore()
        // Write access is requested on the explicit Save action, including every associated sample type.
        try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
        let missing = Self.shareTypes.filter { store.authorizationStatus(for: $0) != .sharingAuthorized }
        guard missing.isEmpty else { throw RecoveryHealthError.writeAccessRequired }

        // A retry with the same sample identity can recover a completed save without creating another workout.
        if let existing = try await existingWorkout(for: activity, store: store) {
            return SampleWorkoutReceipt(id: existing.uuid, activity: activity)
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
        let samples = Self.quantitySamples(for: activity)
        do {
            try await builder.beginCollection(at: activity.startDate)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.addMetadata(Self.metadata(for: activity.id, suffix: "workout")) { success, error in
                    Self.resume(continuation, success: success, error: error)
                }
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samples) { success, error in
                    Self.resume(continuation, success: success, error: error)
                }
            }
            try await builder.endCollection(at: activity.endDate)
            let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
                builder.finishWorkout { workout, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: workout) }
                }
            }
            // nil workout + nil error is documented success when the device locks during saving.
            return SampleWorkoutReceipt(id: workout?.uuid, activity: activity)
        } catch {
            builder.discardWorkout()
            // discardWorkout does not remove samples already added. Delete only this
            // attempt's energy, distance, and heart-rate objects, never a broad date range.
            do {
                try await store.delete(samples)
            } catch {
                if !Self.isNoData(error) {
                    throw RecoveryHealthError.incompleteCleanup
                }
            }
            throw error
        }
    }

    nonisolated static func quantitySamples(for activity: SampleWorkoutActivity) -> [HKQuantitySample] {
        [
            HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: activity.energyKilocalories),
                start: activity.startDate, end: activity.endDate,
                metadata: metadata(for: activity.id, suffix: "energy")
            ),
            HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: activity.distanceMeters),
                start: activity.startDate, end: activity.endDate,
                metadata: metadata(for: activity.id, suffix: "distance")
            ),
            HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    doubleValue: activity.averageHeartRateBPM
                ),
                start: activity.startDate, end: activity.endDate,
                metadata: metadata(for: activity.id, suffix: "heart-rate")
            )
        ]
    }

    nonisolated static func metadata(for id: UUID, suffix: String) -> [String: Any] {
        [
            HKMetadataKeyWorkoutBrandName: "Trailmark Sample Activity",
            HKMetadataKeyIndoorWorkout: true,
            HKMetadataKeyWasUserEntered: true,
            HKMetadataKeySyncIdentifier: "com.trailmark.assignment3.\(id.uuidString).\(suffix)",
            HKMetadataKeySyncVersion: 1
        ]
    }

    private func existingWorkout(for activity: SampleWorkoutActivity, store: HKHealthStore) async throws -> HKWorkout? {
        let syncID = "com.trailmark.assignment3.\(activity.id.uuidString).workout"
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncID])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error, !Self.isNoData(error) { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKWorkout) }
            }
            store.execute(query)
        }
    }

    private func availableStore() throws -> HKHealthStore {
        guard let healthStore else { throw RecoveryHealthError.unavailable }
        return healthStore
    }

    nonisolated private static func isNoData(_ error: Error) -> Bool {
        (error as? HKError)?.code == .errorNoData
    }

    nonisolated private static func resume(_ continuation: CheckedContinuation<Void, Error>, success: Bool, error: Error?) {
        if let error { continuation.resume(throwing: error) }
        else if success { continuation.resume() }
        else { continuation.resume(throwing: RecoveryHealthError.saveFailed) }
    }
}

private enum RecoveryHealthError: LocalizedError {
    case unavailable
    case writeAccessRequired
    case saveFailed
    case incompleteCleanup

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Health data is unavailable on this device."
        case .writeAccessRequired:
            "Allow Trailmark to write Workouts, Active Energy, Walking + Running Distance, and Heart Rate in Health, then try again."
        case .saveFailed:
            "HealthKit did not finish saving the sample workout. Try again."
        case .incompleteCleanup:
            "The workout was not completed and sample cleanup could not be confirmed. Check Health for Trailmark energy, distance, and heart-rate entries before retrying."
        }
    }
}
