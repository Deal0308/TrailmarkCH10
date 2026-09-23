#if os(watchOS)
import Foundation
import Observation

/// Health is an opt-in feature, never a prerequisite for opening the watch app.
@MainActor
@Observable
public final class LiveVitalsViewModel {
    public private(set) var snapshot: LiveVitalsSnapshot = .empty
    public private(set) var phase: LiveVitalsPhase = .idle
    public private(set) var errorMessage: String?
    /// Records the user's choice to use Health, not a claim of read authorization.
    public private(set) var isHealthEnabled = false
    public let unavailableReason: String?
    public let workoutViewModel: WorkoutViewModel?

    @ObservationIgnored private let service: any LiveVitalsProviding
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var authorizationGeneration = 0

    public init(service: any LiveVitalsProviding, workoutViewModel: WorkoutViewModel? = nil) {
        self.service = service
        self.workoutViewModel = workoutViewModel
        unavailableReason = service.liveVitalsUnavailableReason
        service.onLiveVitals = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        service.onLiveVitalsError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    /// Reuse the active workout's sensor stream before its samples are saved to
    /// Health. Daily totals still come from HealthKit's cumulative statistics.
    public var displayedSnapshot: LiveVitalsSnapshot {
        guard usesWorkoutHeartRate, let metrics = workoutViewModel?.metrics else { return snapshot }
        return LiveVitalsSnapshot(
            heartRateBPM: metrics.currentHeartRateBPM,
            stepsToday: snapshot.stepsToday,
            activeEnergyKilocaloriesToday: snapshot.activeEnergyKilocaloriesToday,
            heartRateSampleDate: metrics.heartRateSampleDate,
            updatedAt: snapshot.updatedAt
        )
    }

    public var heartRateSourceText: String {
        usesWorkoutHeartRate ? "Workout heart rate" : "Latest Health sample"
    }

    private var usesWorkoutHeartRate: Bool {
        guard isHealthEnabled, phase == .streaming,
              let metrics = workoutViewModel?.metrics, metrics.state == .running,
              metrics.currentHeartRateBPM != nil, let date = metrics.heartRateSampleDate else { return false }
        return date >= (snapshot.heartRateSampleDate ?? .distantPast)
    }

    public var statusText: String {
        if let unavailableReason { return unavailableReason }
        switch phase {
        case .idle where !isHealthEnabled:
            return "Health is optional. Enable it when you're ready to see your vitals."
        case .idle:
            return "Updates paused while this page is away."
        case .requestingAuthorization:
            return "Requesting Health access…"
        case .streaming where usesWorkoutHeartRate:
            return "Workout BPM · Daily totals from Health"
        case .streaming where snapshot.hasReadableData:
            return snapshot.updateText
        case .streaming:
            return "No readable samples yet. Other pages are ready to use."
        case .failed:
            return "Health could not connect. You can still use the other pages."
        }
    }

    /// Forwarding page/scene visibility never triggers Health authorization.
    public func setActive(_ active: Bool) {
        isActive = active
        if !active {
            service.stopLiveVitalsUpdates()
            // The system authorization sheet can make the scene inactive. Keep
            // that request in flight; enableHealth checks visibility on return.
            if phase == .streaming { phase = .idle }
        } else if isHealthEnabled, phase == .idle {
            resumeUpdates()
        }
    }

    public func enableHealth() async {
        guard unavailableReason == nil, phase != .requestingAuthorization, isActive else { return }
        authorizationGeneration += 1
        let generation = authorizationGeneration
        phase = .requestingAuthorization
        errorMessage = nil
        do {
            try await service.requestLiveVitalsAuthorization()
            guard generation == authorizationGeneration else { return }
            guard !Task.isCancelled else { phase = .idle; return }
            isHealthEnabled = true
            phase = .idle
            if isActive { resumeUpdates() }
        } catch {
            guard generation == authorizationGeneration else { return }
            phase = error is CancellationError ? .idle : .failed
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
    }

    public func continueWithoutHealth() {
        authorizationGeneration += 1
        service.stopLiveVitalsUpdates()
        isHealthEnabled = false
        snapshot = .empty
        errorMessage = nil
        phase = .idle
    }

    public func retry() async {
        errorMessage = nil
        if isHealthEnabled {
            service.stopLiveVitalsUpdates()
            phase = .idle
            if isActive { resumeUpdates() }
        } else {
            await enableHealth()
        }
    }

    private func resumeUpdates() {
        guard isActive, isHealthEnabled, phase != .streaming else { return }
        do {
            try service.startLiveVitalsUpdates()
            phase = .streaming
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }
}
#endif
