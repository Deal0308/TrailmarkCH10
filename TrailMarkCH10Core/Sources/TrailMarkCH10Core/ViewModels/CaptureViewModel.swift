#if os(iOS)
import Foundation
import Observation

@MainActor
@Observable
public final class CaptureViewModel {
    public var type: JournalMediaType = .audio
    public private(set) var saved = false
    public private(set) var isSaving = false
    public private(set) var saveError: String?
    public let service = MediaCaptureService()
    @ObservationIgnored private let journal: JournalViewModel
    private var context: MemoCaptureContext?
    public init(journal: JournalViewModel) {
        self.journal = journal
        service.onStarted = { [weak self] in self?.captureAssociation() }
        service.onFinished = { [weak self] in Task { await self?.save() } }
    }
    /// Exposes the package's shared recorder state without a platform-framework dependency.
    public var phase: CapturePhase { service.phase }
    public var errorMessage: String? { saveError ?? service.errorMessage }
    public var title: String { type == .audio ? "Voice Memo" : "Video Memo" }
    public var startedAt: Date? { service.recordingStartedAt }
    public var associationMessage: String {
        if let context {
            if context.journeyID != nil {
                return context.coordinate == nil ? "Associated with your journey. No recent GPS fix was available at recording start, so this memo has no map pin." : "This memo is linked to your journey and its location at recording start."
            }
            return "This memo is saved to your Field Journal."
        }
        return journal.activeJourneyTitle.map { "Record for \($0). A recent GPS fix adds a map pin." } ?? "Start a journey first to associate and geotag a new memo."
    }

    public func record() async {
        context = nil
        saveError = nil
        await service.start(type: type)
    }
    public func stop() { service.stop() }
    public func cancel() { service.cancel() }
    public func suspend() {
        if phase == .recording { service.stop() }
        else if phase == .preparing {
            service.cancel()
            saveError = "Recording preparation was cancelled when the app entered the background. Tap Record to try again."
        }
    }

    private func captureAssociation() {
        let captured = journal.captureContext()
        context = MemoCaptureContext(date: service.recordingStartedAt ?? captured.date, journeyID: captured.journeyID, coordinate: captured.coordinate)
    }

    public func save() async {
        guard !saved, !isSaving, let media = service.result, let context else { return }
        isSaving = true
        defer { isSaving = false }
        do { try await journal.save(media, context: context); saved = true; saveError = nil }
        catch { saveError = "Recording is still available here. Retry saving before closing: \(error.localizedDescription)" }
    }
}
#endif
