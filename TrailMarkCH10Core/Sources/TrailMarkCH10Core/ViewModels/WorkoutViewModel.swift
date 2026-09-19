#if os(iOS) || os(watchOS)
import Foundation
import Observation

/// Shared observable state for the iPhone Workout tab and watch workout screen.
@MainActor
@Observable
public final class WorkoutViewModel {
    public private(set) var metrics: WorkoutMetrics = .idle
    public private(set) var errorMessage: String?
    @ObservationIgnored private let service: WorkoutSessionService

    public init(service: WorkoutSessionService = WorkoutSessionService()) {
        self.service = service
        service.onMetrics = { [weak self] metrics in
            self?.metrics = metrics
            if metrics.state != .failed { self?.errorMessage = nil }
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
