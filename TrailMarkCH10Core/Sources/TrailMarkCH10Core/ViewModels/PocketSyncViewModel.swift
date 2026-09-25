#if os(iOS) || os(watchOS)
import Foundation
import Observation

@MainActor
@Observable
public final class PocketSyncViewModel {
    @ObservationIgnored private let service: PocketSyncService
    public init(service: PocketSyncService) { self.service = service }
    public var statusText: String { service.statusMessage }
    public var errorMessage: String? { service.errorMessage }
    public var isWorking: Bool { service.isWorking }
    public var summary: PocketSyncSummary? { service.lastReceivedSummary }
    public func retry() { service.retry() }
}
#endif
