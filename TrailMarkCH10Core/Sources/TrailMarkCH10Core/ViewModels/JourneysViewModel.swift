import Foundation
import Observation

@MainActor
@Observable
public final class JourneysViewModel {
    public private(set) var journeys: [Journey] = []
    public private(set) var activeJourney: Journey?
    public private(set) var errorMessage: String?
    public private(set) var loadingHealthIDs: Set<UUID> = []
    public private(set) var healthErrors: [UUID: String] = [:]
    public private(set) var latestPocketSyncSummary: PocketSyncSummary?
    public private(set) var pocketSyncMessage: String?
    public private(set) var feedback: UserFeedback?
    public var searchText = ""
    public let location: LocationService
    @ObservationIgnored private var requestedHealthRefreshes: Set<UUID> = []
    @ObservationIgnored private let store: JourneyStore
    @ObservationIgnored private let healthService: any ActivityHealthProviding

    public init(store: JourneyStore, location: LocationService? = nil, healthService: (any ActivityHealthProviding)? = nil) {
        self.store = store
        self.location = location ?? LocationService()
        self.healthService = healthService ?? ActivityHealthService()
        reload()
        self.location.onPoint = { [weak self] point, distance in self?.append(point, distance: distance) }
    }

    public func journey(id: UUID) -> Journey? {
        if activeJourney?.id == id { return activeJourney }
        return journeys.first { $0.id == id }
    }

    @discardableResult
    public func start(title: String) -> Bool {
        guard activeJourney == nil else { return false }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let journey = Journey(title: trimmed.isEmpty ? "Journey \(Date().formatted(date: .abbreviated, time: .shortened))" : trimmed)
        do {
            try store.save(journey)
            activeJourney = journey
            errorMessage = nil
            reload()
            location.start()
            feedback = UserFeedback("Journey started", message: "Keep Trailmark open for route recording. Add memos from the Journal tab.")
            return true
        } catch {
            errorMessage = "Journey could not be started: \(error.localizedDescription)"
            return false
        }
    }

    public func finish() async {
        guard var journey = activeJourney else { return }
        journey.endDate = Date()
        journey.status = .completed
        do {
            try store.save(journey)
            location.stop()
            activeJourney = nil
            errorMessage = nil
            reload()
            feedback = UserFeedback("Journey saved", message: "Your route and memos are saved. Health readings can be refreshed whenever you like.")
            await refreshHealth(id: journey.id)
        } catch { errorMessage = "Could not save the completed journey. Your route is still active; retry Finish. \(error.localizedDescription)" }
    }

    public func refreshHealth(id: UUID) async {
        guard !loadingHealthIDs.contains(id) else {
            requestedHealthRefreshes.insert(id)
            return
        }
        loadingHealthIDs.insert(id)
        defer { loadingHealthIDs.remove(id) }
        repeat {
            requestedHealthRefreshes.remove(id)
            guard let snapshot = journey(id: id) else { return }
            healthErrors[id] = nil
            do {
                let summary = try await healthService.readActivity(from: snapshot.startDate, to: snapshot.endDate ?? Date())
                // Re-read after awaiting HealthKit so new route points are never overwritten.
                guard var latest = journey(id: id) else { return }
                latest.health = summary
                try store.save(latest)
                if activeJourney?.id == id { activeJourney = latest }
                reload()
            } catch { healthErrors[id] = "Health summary unavailable: \(error.localizedDescription)" }
            // Finishing during a read schedules a final query with the saved end time.
        } while requestedHealthRefreshes.contains(id)
    }

    public func captureContext() -> MemoCaptureContext {
        let now = Date()
        let point = location.latestPoint.flatMap { abs($0.timestamp.timeIntervalSince(now)) <= 20 ? $0 : nil }
        return MemoCaptureContext(date: now, journeyID: activeJourney?.id, coordinate: activeJourney == nil ? nil : point)
    }

    public func setForeground(_ foreground: Bool) { location.setForeground(foreground) }
    public func clearError() { errorMessage = nil }
    public func dismissFeedback() { feedback = nil }
    public var savedJourneys: [Journey] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return journeys.filter {
            $0.id != activeJourney?.id && (query.isEmpty || "\($0.title) \($0.startDate.formatted(date: .long, time: .omitted))".localizedStandardContains(query))
        }
    }

    /// Idempotently turns a completed watch workout into the same Journey model
    /// used by locally recorded iPhone routes.
    @discardableResult
    public func importWatchActivity(_ record: WatchActivityRecord) -> Bool {
        if let existing = journey(id: record.id), existing.watchActivity == record {
            pocketSyncMessage = "Activity received from Apple Watch."
            return true
        }
        var journey = Journey(id: record.id, title: "Apple Watch walk", startDate: record.startDate)
        journey.endDate = record.endDate
        journey.status = .completed
        journey.watchActivity = record
        // Workout totals are presented separately from queried iPhone Health data.
        journey.health = nil
        do {
            try store.save(journey)
            errorMessage = nil
            pocketSyncMessage = "Activity received from Apple Watch."
            reload()
            feedback = UserFeedback("Watch activity received", message: "Open Apple Watch walk below to see your activity and attached memos.")
            return true
        } catch {
            errorMessage = "The Apple Watch activity arrived but could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    public func receivePocketSyncSummary(_ summary: PocketSyncSummary) {
        latestPocketSyncSummary = summary
    }

    private func append(_ point: GeoPoint, distance: Double) {
        guard var journey = activeJourney else { return }
        journey.points.append(point)
        journey.distanceMeters += distance
        activeJourney = journey
        do { try store.save(journey); errorMessage = nil; reload() }
        catch { errorMessage = "Route checkpoint could not be saved. Keep the app open and retry Finish. \(error.localizedDescription)" }
    }

    private func reload() { journeys = store.journeys.sorted { $0.startDate > $1.startDate } }
}
