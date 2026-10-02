#if os(watchOS)
import Foundation

/// Watch live-query contract. It exposes only app models, never HealthKit types.
@MainActor
public protocol LiveVitalsProviding: AnyObject {
    var onLiveVitals: ((LiveVitalsSnapshot) -> Void)? { get set }
    var onLiveVitalsError: ((String) -> Void)? { get set }
    var liveVitalsUnavailableReason: String? { get }

    func requestLiveVitalsAuthorization() async throws
    func startLiveVitalsUpdates() throws
    func stopLiveVitalsUpdates()
}
#endif
