#if os(watchOS)
import Foundation

/// Watch live-query contract. It exposes only app models, never HealthKit types.
@MainActor
public protocol LiveVitalsProviding: AnyObject {
    var onLiveVitals: ((LiveVitalsSnapshot) -> Void)? { get set }
    var onLiveVitalsError: ((String) -> Void)? { get set }

    func startLiveVitalsUpdates() async throws
    func stopLiveVitalsUpdates()
}
#endif
