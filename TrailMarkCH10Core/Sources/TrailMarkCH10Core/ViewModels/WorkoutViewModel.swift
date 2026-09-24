#if os(iOS) || os(watchOS)
import Foundation
import Observation

/// Shared observable state for the iPhone Workout tab and watch workout screen.
@MainActor
@Observable
public final class WorkoutViewModel {
    public private(set) var metrics: WorkoutMetrics = .idle
    public private(set) var errorMessage: String?
    public private(set) var pocketSyncMessage: String?
    @ObservationIgnored private let service: WorkoutSessionService
    @ObservationIgnored private let pocketSync: PocketSyncService?

    public init(service: WorkoutSessionService = WorkoutSessionService(), pocketSync: PocketSyncService? = nil) {
        self.service = service
        self.pocketSync = pocketSync
        service.onMetrics = { [weak self] metrics in
            self?.metrics = metrics
            if metrics.state != .failed { self?.errorMessage = nil }
            #if os(watchOS)
            self?.pocketSync?.observeWorkout(metrics)
            #endif
            if metrics.state == .completed, self?.pocketSync != nil {
                self?.pocketSyncMessage = "Activity queued for iPhone Journeys."
            } else if metrics.state == .requestingAuthorization {
                self?.pocketSyncMessage = nil
            }
        }
        service.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    public func start() async {
        errorMessage = nil
        await service.start()
    }

    public func pauseOrResume() {
        if metrics.state == .paused { service.resume() }
        else if metrics.state == .running { service.pause() }
    }

    public func end() { service.end() }
}
#endif
