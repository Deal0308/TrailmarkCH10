#if os(iOS)
import Foundation
import Observation

@MainActor
@Observable
public final class MediaDetailViewModel {
    public let item: JournalMedia
    public let playback = MediaPlaybackService()
    public private(set) var isReady = false
    public private(set) var errorMessage: String?
    public private(set) var deleted = false
    public private(set) var isDeleting = false
    public private(set) var audioState = AudioPlaybackState()
    public private(set) var waveform: [Float] = []
    public private(set) var isLoadingWaveform = false
    @ObservationIgnored private let audio = AudioPlaybackService()
    @ObservationIgnored private var playbackUpdates: Task<Void, Never>?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private let journal: JournalViewModel
    public init(item: JournalMedia, journal: JournalViewModel) { self.item = item; self.journal = journal }

    public func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        pause()
        isReady = false
        errorMessage = nil
        waveform = []
        isLoadingWaveform = false
        do {
            let url = try journal.store.fileURL(for: item)
            if item.type == .audio {
                try audio.prepare(url: url)
                audioState = audio.snapshot()
                isReady = true
                isLoadingWaveform = true
                let samples = await AudioWaveformService.amplitudes(url: url)
                guard generation == loadGeneration else { return }
                isLoadingWaveform = false
                try Task.checkCancellation()
                waveform = samples
            } else {
                try await playback.prepare(url: url) { [weak self] message in
                    self?.errorMessage = message
                    self?.isReady = false
                }
                try Task.checkCancellation()
                guard generation == loadGeneration else { return }
                isReady = true
            }
        } catch is CancellationError {
            if generation == loadGeneration { pause() }
        } catch {
            guard generation == loadGeneration else { return }
            isReady = false
            errorMessage = error.localizedDescription
        }
    }

    public func toggleAudioPlayback() {
        guard isReady, item.type == .audio else { return }
        if audioState.isPlaying { pause(); return }
        do {
            try audio.play()
            errorMessage = nil
            audioState = audio.snapshot()
            playbackUpdates?.cancel()
            // Polling belongs to the view model; the view only renders snapshots.
            playbackUpdates = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    audioState = audio.snapshot()
                    if let error = audio.errorMessage { errorMessage = error }
                    guard audioState.isPlaying else { audio.pause(); return }
                    do { try await Task.sleep(for: .milliseconds(50)) }
                    catch { return }
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    public func seekAudio(to fraction: Double) {
        audio.seek(to: fraction)
        audioState = audio.snapshot()
    }

    public func pause() {
        playbackUpdates?.cancel()
        playbackUpdates = nil
        if item.type == .audio { audio.pause(); audioState = audio.snapshot() }
        else { playback.pause() }
    }
    public func delete() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        loadGeneration += 1
        isLoadingWaveform = false
        pause()
        if item.type == .audio { audio.stop() }
        else { playback.stop() }
        deleted = await journal.delete(item)
        if !deleted { isReady = false; errorMessage = journal.errorMessage }
    }
}
#endif
