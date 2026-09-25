import Foundation
import Observation

@MainActor
@Observable
public final class TodayViewModel {
    public private(set) var activitySummary = ActivitySummary.empty
    public private(set) var metrics: JourneyHealthSummary?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var hasCompletedInitialLoad = false
    public private(set) var showingPreviousReadings = false
    @ObservationIgnored private let service: any ActivityHealthProviding

    public init(service: (any ActivityHealthProviding)? = nil) {
        self.service = service ?? ActivityHealthService()
    }

    public var hasReadableData: Bool {
        guard let metrics else { return false }
        return metrics.steps != nil || metrics.distanceMeters != nil || metrics.activeEnergyKilocalories != nil || metrics.hydrationMilliliters != nil
    }

    public func loadInitialData() async {
        guard !hasCompletedInitialLoad || metrics.map({ !Calendar.current.isDateInToday($0.queriedAt) }) == true else { return }
        await refreshToday()
    }

    public func retry() async { await refreshToday() }

    public func refreshToday() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasCompletedInitialLoad = true }
        do {
            let range = TodayDateRangeProvider.range()
            let result = try await service.readActivity(from: range.startDate, to: range.endDate)
            metrics = result
            showingPreviousReadings = false
            activitySummary = ActivitySummary(steps: Int((result.steps ?? 0).rounded()), distanceMeters: result.distanceMeters ?? 0, activeEnergyKilocalories: result.activeEnergyKilocalories ?? 0, hydrationMilliliters: result.hydrationMilliliters ?? 0, date: range.endDate)
        } catch {
            // Keep same-day readings useful during a failed refresh, clearly marked stale.
            if let metrics, Calendar.current.isDateInToday(metrics.queriedAt) {
                showingPreviousReadings = true
            } else {
                metrics = nil
                activitySummary = .empty
                showingPreviousReadings = false
            }
            errorMessage = error.localizedDescription
        }
    }
}

/// Source compatibility for earlier course code; the implementation is now a view model.
public typealias HealthKitManager = TodayViewModel
