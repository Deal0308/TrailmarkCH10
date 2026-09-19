#if os(watchOS)
import Foundation
import Observation

/// Shared-package state and actions for the essentials-only watch memo flow.
/// The watch app renders this state without importing AVFoundation or doing file I/O.
@MainActor
@Observable
public final class WatchMemoViewModel {
    public private(set) var items: [JournalMedia] = []
    public private(set) var phase: CapturePhase = .idle
    public private(set) var recordingStartedAt: Date?
    public private(set) var playingItemID: UUID?
    public private(set) var playbackState = AudioPlaybackState()
    public private(set) var errorMessage: String?
    public private(set) var statusMessage = "Record a short trail note."

    public let maximumDuration: TimeInterval = 60

    @ObservationIgnored private var store: JournalMediaStore?
    @ObservationIgnored private let recorder = WatchAudioMemoService()
    @ObservationIgnored private let player = AudioPlaybackService()
    @ObservationIgnored private var recordingLimitTask: Task<Void, Never>?
    @ObservationIgnored private var playbackUpdates: Task<Void, Never>?
    @ObservationIgnored private var pendingCapture: CapturedMedia?

    public init(store: JournalMediaStore? = nil) {
        do {
            self.store = try store ?? JournalMediaStore()
            reload()
        } catch {
            self.store = nil
            errorMessage = "Voice-memo storage could not be opened: \(error.localizedDescription)"
            statusMessage = "Storage unavailable."
        }
    }

    public var isRecording: Bool { phase == .recording }
    public var isSaving: Bool { phase == .finishing }
    public var hasPendingCapture: Bool { pendingCapture != nil }
    public var isStorageAvailable: Bool { store != nil }

    public func retryStorage() {
        guard store == nil else { reload(); return }
        do {
            store = try JournalMediaStore()
            errorMessage = nil
            statusMessage = "Ready to record."
            reload()
        } catch {
            errorMessage = "Voice-memo storage could not be opened: \(error.localizedDescription)"
        }
    }

    public func startRecording() async {
        guard phase == .idle || phase == .failed else { return }
        guard store != nil else { retryStorage(); return }
        discardPendingCapture()
        pausePlayback()
        errorMessage = nil
        phase = .preparing
        statusMessage = "Preparing microphone…"

        do {
            recordingStartedAt = try await recorder.start()
            phase = .recording
            statusMessage = "Recording on Apple Watch"
            recordingLimitTask?.cancel()
            recordingLimitTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                await self?.stopAndSave()
            }
        } catch {
            phase = .failed
            recordingStartedAt = nil
            errorMessage = error.localizedDescription
            statusMessage = "Recording unavailable."
        }
    }

    public func stopAndSave() async {
        guard phase == .recording else { return }
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        phase = .finishing
        statusMessage = "Saving memo…"

        do {
            pendingCapture = try recorder.stop()
            try await savePendingCapture()
        } catch {
            phase = .failed
            if pendingCapture == nil { recordingStartedAt = nil }
            errorMessage = error.localizedDescription
            statusMessage = pendingCapture == nil ? "Recording could not finish." : "Memo is waiting to be saved."
        }
    }

    public func retrySaving() async {
        guard pendingCapture != nil else { return }
        phase = .finishing
        errorMessage = nil
        statusMessage = "Saving memo…"
        do { try await savePendingCapture() }
        catch {
            phase = .failed
            errorMessage = error.localizedDescription
            statusMessage = "Memo is waiting to be saved."
        }
    }

    public func cancelRecording() {
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        recorder.cancel()
        discardPendingCapture()
        recordingStartedAt = nil
        phase = .idle
        errorMessage = nil
        statusMessage = "Recording discarded."
    }

    public func preparePlayback(for item: JournalMedia) {
        guard item.type == .audio, playingItemID != item.id else { return }
        pausePlayback()
        do {
            guard let store else { throw WatchMemoViewModelError.storageUnavailable }
            try player.prepare(url: store.fileURL(for: item))
            playingItemID = item.id
            playbackState = player.snapshot()
            errorMessage = nil
        } catch {
            playingItemID = nil
            playbackState = AudioPlaybackState()
            errorMessage = "This memo could not be prepared: \(error.localizedDescription)"
        }
    }

    public func togglePlayback(for item: JournalMedia) {
        if playingItemID != item.id { preparePlayback(for: item) }
        guard playingItemID == item.id else { return }
        if playbackState.isPlaying { pausePlayback(); return }

        do {
            try player.play()
            errorMessage = nil
            playbackState = player.snapshot()
            playbackUpdates?.cancel()
            playbackUpdates = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    playbackState = player.snapshot()
                    if let playbackError = player.errorMessage {
                        errorMessage = playbackError
                        player.pause()
                        playbackState = player.snapshot()
                        return
                    }
                    guard playbackState.isPlaying else {
                        player.pause()
                        return
                    }
                    do { try await Task.sleep(for: .milliseconds(200)) }
                    catch { return }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            playbackState = player.snapshot()
        }
    }

    public func pausePlayback() {
        playbackUpdates?.cancel()
        playbackUpdates = nil
        player.pause()
        playbackState = player.snapshot()
    }

    public func delete(_ item: JournalMedia) async {
        guard let store else { return }
        if playingItemID == item.id {
            pausePlayback()
            player.stop()
            playingItemID = nil
            playbackState = AudioPlaybackState()
        }
        do {
            try await Task.detached(priority: .userInitiated) { try store.delete(item) }.value
            errorMessage = nil
            statusMessage = "Memo deleted."
            reload()
        } catch {
            errorMessage = "Memo deletion could not finish: \(error.localizedDescription)"
            reload()
        }
    }

    public func reload() {
        items = store?.media.filter { $0.type == .audio } ?? []
    }

    private func savePendingCapture() async throws {
        guard let capture = pendingCapture else { throw WatchMemoViewModelError.recordingUnavailable }
        guard let store else { throw WatchMemoViewModelError.storageUnavailable }
        let capturedAt = recordingStartedAt ?? Date()
        _ = try await Task.detached(priority: .userInitiated) {
            try store.importMedia(
                from: capture.url,
                type: .audio,
                date: capturedAt,
                duration: capture.duration
            )
        }.value
        MediaFileService.removeTemporaryFile(capture.url)
        pendingCapture = nil
        recordingStartedAt = nil
        phase = .idle
        errorMessage = nil
        statusMessage = "Voice memo saved."
        reload()
    }

    private func discardPendingCapture() {
        if let pendingCapture { MediaFileService.removeTemporaryFile(pendingCapture.url) }
        pendingCapture = nil
    }
}

private enum WatchMemoViewModelError: LocalizedError {
    case storageUnavailable
    case recordingUnavailable

    var errorDescription: String? {
        switch self {
        case .storageUnavailable: "Voice-memo storage is unavailable."
        case .recordingUnavailable: "The completed recording is unavailable."
        }
    }
}
#endif
