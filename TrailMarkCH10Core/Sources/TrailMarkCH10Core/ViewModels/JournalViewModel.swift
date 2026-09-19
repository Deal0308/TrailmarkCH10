#if os(iOS)
import Foundation
import Observation

@MainActor
@Observable
public final class JournalViewModel {
    public private(set) var items: [JournalMedia] = []
    public private(set) var thumbnails: [UUID: Data] = [:]
    public private(set) var errorMessage: String?
    public private(set) var isImporting = false
    @ObservationIgnored let store: JournalMediaStore
    private var journeys: JourneysViewModel?

    public init(store: JournalMediaStore, journeys: JourneysViewModel?) {
        self.store = store
        self.journeys = journeys
        reload()
    }
    public func connect(journeys: JourneysViewModel?) { self.journeys = journeys }
    public var activeJourneyTitle: String? { journeys?.activeJourney?.title }
    public func media(for journeyID: UUID) -> [JournalMedia] { items.filter { $0.journeyID == journeyID } }
    public func captureContext() -> MemoCaptureContext { journeys?.captureContext() ?? MemoCaptureContext() }
    public func makeCaptureViewModel() -> CaptureViewModel { CaptureViewModel(journal: self) }
    public func makeDetailViewModel(item: JournalMedia) -> MediaDetailViewModel { MediaDetailViewModel(item: item, journal: self) }
    public func clearError() { errorMessage = nil }
    public func reportError(_ message: String) { errorMessage = message }
    public func reload() { items = store.media }

    public func delete(_ item: JournalMedia) async -> Bool {
        do {
            try await Task.detached(priority: .userInitiated) { [store] in try store.delete(item) }.value
            thumbnails[item.id] = nil
            errorMessage = nil
            reload()
            return true
        } catch {
            reload()
            errorMessage = "Memo deletion could not finish: \(error.localizedDescription)"
            return false
        }
    }

    public func save(_ media: CapturedMedia, context: MemoCaptureContext) async throws {
        _ = try await Task.detached(priority: .userInitiated) { [store] in
            try store.importMedia(from: media.url, type: media.type, date: context.date, duration: media.duration, journeyID: context.journeyID, coordinate: context.coordinate)
        }.value
        MediaFileService.removeTemporaryFile(media.url)
        reload()
    }

    public func importVideo(url: URL) async {
        guard !isImporting else { MediaFileService.removeTemporaryFile(url); return }
        isImporting = true
        errorMessage = nil
        // An imported clip wasn't captured at the current GPS position. Associate it
        // with the active journey, but never invent its capture location.
        let context = captureContext()
        defer { isImporting = false; MediaFileService.removeTemporaryFile(url) }
        do {
            let duration = try await MediaPlaybackService.videoDuration(url: url)
            _ = try await Task.detached(priority: .userInitiated) { [store] in
                try store.importMedia(from: url, type: .video, date: Date(), duration: duration, journeyID: context.journeyID, coordinate: nil, isImported: true)
            }.value
            reload()
        } catch { errorMessage = "Video import failed: \(error.localizedDescription)" }
    }

    public func loadThumbnail(for item: JournalMedia) async {
        guard item.type == .video, thumbnails[item.id] == nil, let url = try? store.fileURL(for: item) else { return }
        let data = await MediaPlaybackService.thumbnailData(url: url)
        guard items.contains(where: { $0.id == item.id }) else { return }
        thumbnails[item.id] = data
    }
}
#endif
