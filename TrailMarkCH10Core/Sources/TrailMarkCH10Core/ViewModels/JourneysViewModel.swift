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

    public func start(title: String) {
        guard activeJourney == nil else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let journey = Journey(title: trimmed.isEmpty ? "Journey \(Date().formatted(date: .abbreviated, time: .shortened))" : trimmed)
        do {
            try store.save(journey)
            activeJourney = journey
            errorMessage = nil
            reload()
            location.start()
        } catch { errorMessage = "Journey could not be started: \(error.localizedDescription)" }
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
