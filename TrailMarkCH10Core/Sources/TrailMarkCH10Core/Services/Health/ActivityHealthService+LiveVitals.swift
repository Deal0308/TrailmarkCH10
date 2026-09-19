#if os(watchOS)
import Foundation
import HealthKit

/// Watch-only streaming additions on the same HealthKit manager used by Today.
/// HealthKit performs the aggregation so steps from multiple sources are not
/// manually added or double-counted.
extension ActivityHealthService: LiveVitalsProviding {
    public func startLiveVitalsUpdates() async throws {
        guard !isLiveVitalsStreaming else {
            onLiveVitals?(liveVitalsSnapshot)
            return
        }
        guard let store else { throw LiveVitalsHealthError.unavailable }
        liveVitalsStartGeneration += 1
        let startGeneration = liveVitalsStartGeneration

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
        guard !Task.isCancelled, startGeneration == liveVitalsStartGeneration else {
            throw CancellationError()
        }

        isLiveVitalsStreaming = true
        let dayStart = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        if liveVitalsDayStart != dayStart {
            liveVitalsSnapshot = .empty
        }
        installLiveVitalsQueries(dayStart: dayStart)
        scheduleLiveVitalsDayRollover(from: dayStart)
    }

    public func stopLiveVitalsUpdates() {
        liveVitalsStartGeneration += 1
        isLiveVitalsStreaming = false
        liveVitalsRolloverTask?.cancel()
        liveVitalsRolloverTask = nil
        stopLiveVitalsQueries()
    }

    private func installLiveVitalsQueries(dayStart: Date) {
        guard let store else { return }
        stopLiveVitalsQueries()
        liveVitalsDayStart = dayStart
        liveVitalsQueryGeneration += 1
        let generation = liveVitalsQueryGeneration

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: nil,
            options: .strictStartDate
        )
        let interval = DateComponents(day: 1)
        let queries = LiveVitalsMetric.allCases.map { metric in
            let query = HKStatisticsCollectionQuery(
                quantityType: metric.quantityType,
                quantitySamplePredicate: predicate,
                options: metric.statisticsOptions,
                anchorDate: dayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { [weak self] _, collection, error in
                let statistics = collection?.statistics(for: Date())
                Task { @MainActor [weak self] in
                    self?.receiveLiveVitalsStatistics(
                        statistics,
                        metric: metric,
                        generation: generation,
                        error: error
                    )
                }
            }
            query.statisticsUpdateHandler = { [weak self] _, statistics, collection, error in
                let currentStatistics = collection?.statistics(for: Date()) ?? statistics
                Task { @MainActor [weak self] in
                    self?.receiveLiveVitalsStatistics(
                        currentStatistics,
                        metric: metric,
                        generation: generation,
                        error: error
                    )
                }
            }
            return query
        }

        liveVitalsQueries = queries
        queries.forEach(store.execute)
    }

    private func stopLiveVitalsQueries() {
        guard let store else {
            liveVitalsQueries.removeAll()
            return
        }
        liveVitalsQueries.forEach(store.stop)
        liveVitalsQueries.removeAll()
    }

    private func receiveLiveVitalsStatistics(
        _ statistics: HKStatistics?,
        metric: LiveVitalsMetric,
        generation: Int,
        error: Error?
    ) {
        guard isLiveVitalsStreaming, generation == liveVitalsQueryGeneration else { return }
        if let error {
            onLiveVitalsError?("\(metric.displayName) could not update: \(error.localizedDescription)")
            return
        }

        var heartRate = liveVitalsSnapshot.heartRateBPM
        var steps = liveVitalsSnapshot.stepsToday
        var energy = liveVitalsSnapshot.activeEnergyKilocaloriesToday
        var heartRateDate = liveVitalsSnapshot.heartRateSampleDate

        switch metric {
        case .heartRate:
            heartRate = statistics?.mostRecentQuantity()?.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            heartRateDate = statistics?.mostRecentQuantityDateInterval()?.end
        case .steps:
            steps = statistics?.sumQuantity()?.doubleValue(for: .count())
        case .activeEnergy:
            energy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }

        liveVitalsSnapshot = LiveVitalsSnapshot(
            heartRateBPM: heartRate,
            stepsToday: steps,
            activeEnergyKilocaloriesToday: energy,
            heartRateSampleDate: heartRateDate,
            updatedAt: Date()
        )
        onLiveVitals?(liveVitalsSnapshot)
    }

    private func scheduleLiveVitalsDayRollover(from dayStart: Date) {
        liveVitalsRolloverTask?.cancel()
        guard let nextDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: dayStart) else {
            return
        }
        let waitSeconds = max(1, Int(nextDay.timeIntervalSinceNow.rounded(.up)) + 1)
        liveVitalsRolloverTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(waitSeconds)) }
            catch { return }
            guard let self, isLiveVitalsStreaming else { return }
            let newDayStart = Calendar.autoupdatingCurrent.startOfDay(for: Date())
            liveVitalsSnapshot = .empty
            installLiveVitalsQueries(dayStart: newDayStart)
            onLiveVitals?(liveVitalsSnapshot)
            scheduleLiveVitalsDayRollover(from: newDayStart)
        }
    }
}

private enum LiveVitalsMetric: CaseIterable, Sendable {
    case heartRate
    case steps
    case activeEnergy

    var quantityType: HKQuantityType {
        switch self {
        case .heartRate: HKQuantityType(.heartRate)
        case .steps: HKQuantityType(.stepCount)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        }
    }

    var statisticsOptions: HKStatisticsOptions {
        switch self {
        case .heartRate: .mostRecent
        case .steps, .activeEnergy: .cumulativeSum
        }
    }

    var displayName: String {
        switch self {
        case .heartRate: "Heart rate"
        case .steps: "Steps"
        case .activeEnergy: "Active energy"
        }
    }
}

private enum LiveVitalsHealthError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Health data is unavailable on this Apple Watch."
    }
}
#endif
