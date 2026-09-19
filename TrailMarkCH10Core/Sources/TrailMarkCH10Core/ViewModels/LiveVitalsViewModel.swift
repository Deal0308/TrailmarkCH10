#if os(watchOS)
import Foundation
import Observation

/// Observable, framework-independent state for the watch Live Vitals page.
@MainActor
@Observable
public final class LiveVitalsViewModel {
    public private(set) var snapshot: LiveVitalsSnapshot = .empty
    public private(set) var phase: LiveVitalsPhase = .idle
    public private(set) var errorMessage: String?

    @ObservationIgnored private let service: any LiveVitalsProviding
    @ObservationIgnored private var startGeneration = 0

    public init(service: any LiveVitalsProviding) {
        self.service = service
        service.onLiveVitals = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        service.onLiveVitalsError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    public var statusText: String {
        switch phase {
        case .idle:
            "Open this page to start live updates."
        case .requestingAuthorization:
            "Requesting Health access…"
        case .streaming where snapshot.hasReadableData:
            snapshot.updateText
        case .streaming:
            "Waiting for readable Health samples…"
        case .failed:
            "Live vitals are unavailable."
        }
    }

    public func start() async {
        guard phase != .requestingAuthorization, phase != .streaming else { return }
        startGeneration += 1
        let generation = startGeneration
        phase = .requestingAuthorization
        errorMessage = nil
        do {
            try await service.startLiveVitalsUpdates()
            guard generation == startGeneration, phase == .requestingAuthorization else {
                return
            }
            guard !Task.isCancelled else {
                service.stopLiveVitalsUpdates()
                phase = .idle
                return
            }
            phase = .streaming
        } catch is CancellationError {
            if generation == startGeneration, phase == .requestingAuthorization {
                phase = .idle
            }
        } catch {
            guard generation == startGeneration, phase == .requestingAuthorization else { return }
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    public func stop() {
        startGeneration += 1
        service.stopLiveVitalsUpdates()
        if phase != .failed { phase = .idle }
    }

    public func retry() async {
        stop()
        phase = .idle
        await start()
    }
}
#endif
