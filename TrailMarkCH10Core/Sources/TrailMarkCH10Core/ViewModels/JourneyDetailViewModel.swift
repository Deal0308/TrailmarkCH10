import Foundation
import Observation

#if os(iOS)
@MainActor
@Observable
public final class JourneyDetailViewModel {
    public let journeyID: UUID
    public let journal: JournalViewModel?
    @ObservationIgnored private let journeys: JourneysViewModel
    public init(journeyID: UUID, journeys: JourneysViewModel, journal: JournalViewModel?) {
        self.journeyID = journeyID; self.journeys = journeys; self.journal = journal
    }
    public var journey: Journey? { journeys.journey(id: journeyID) }
    public var memos: [JournalMedia] { journal?.media(for: journeyID) ?? [] }
    public var isActive: Bool { journeys.activeJourney?.id == journeyID }
    public var isLoadingHealth: Bool { journeys.loadingHealthIDs.contains(journeyID) }
    public var healthError: String? { journeys.healthErrors[journeyID] }
    public var routeMessage: String { journeys.location.message }
    public var routeError: String? { journeys.errorMessage }
    public var memosWithoutPins: Int { memos.filter { $0.coordinate == nil }.count }
    public func refreshHealth() async { await journeys.refreshHealth(id: journeyID) }
    public func finish() async { await journeys.finish() }
}
#endif
