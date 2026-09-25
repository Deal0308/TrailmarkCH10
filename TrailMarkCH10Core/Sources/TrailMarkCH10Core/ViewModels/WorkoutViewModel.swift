#if os(iOS) || os(watchOS)
import Foundation
import Observation

/// Shared observable state for the iPhone Workout tab and watch workout screen.
@MainActor
@Observable
public final class WorkoutViewModel {
    public private(set) var metrics: WorkoutMetrics = .idle
    public private(set) var errorMessage: String?
    public var pocketSyncMessage: String? {
        guard metrics.state == .completed, let pocketSync else { return nil }
        return pocketSync.errorMessage ?? pocketSync.statusMessage
    }
    public private(set) var isSendingCommand = false
    public func retrySync() { pocketSync?.retry() }
    @ObservationIgnored private let service: WorkoutSessionService
    @ObservationIgnored private let pocketSync: PocketSyncService?

    public init(service: WorkoutSessionService = WorkoutSessionService(), pocketSync: PocketSyncService? = nil) {
        self.service = service
        self.pocketSync = pocketSync
        service.onCommandPending = { [weak self] in self?.isSendingCommand = $0 }
        service.onMetrics = { [weak self] metrics in
            self?.metrics = metrics
            if metrics.state == .failed, self?.errorMessage == nil {
                self?.errorMessage = "Apple Watch could not complete the workout. Check the watch for details before starting another session."
            }
            #if os(watchOS)
            self?.pocketSync?.observeWorkout(metrics)
            #endif
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
        errorMessage = nil
        if metrics.state == .paused { service.resume() }
        else if metrics.state == .running { service.pause() }
    }

    public func end() { errorMessage = nil; service.end() }
}
#endif
