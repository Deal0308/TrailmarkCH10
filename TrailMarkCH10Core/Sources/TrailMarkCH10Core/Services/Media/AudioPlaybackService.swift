#if os(iOS) || os(watchOS)
import AVFoundation
import Foundation

/// Owns audio playback and metering; no AVAudioPlayer reaches an app view.
@MainActor
public final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    public private(set) var errorMessage: String?

    public func prepare(url: URL) throws {
        stop()
        errorMessage = nil
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .default)
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.duration.isFinite, player.duration > 0, player.prepareToPlay() else {
            throw AudioPlaybackError.unavailable
        }
        player.delegate = self
        player.isMeteringEnabled = true
        self.player = player
    }

    public func play() throws {
        guard let player else { throw AudioPlaybackError.unavailable }
        errorMessage = nil
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        if player.currentTime >= player.duration { player.currentTime = 0 }
        guard player.play() else {
            pause()
            throw AudioPlaybackError.unavailable
        }
    }

    public func pause() {
        player?.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func stop() {
        pause()
        player?.stop()
        player = nil
    }

    public func seek(to fraction: Double) {
        guard let player, fraction.isFinite else { return }
        player.currentTime = min(max(fraction, 0), 1) * player.duration
    }

    public func snapshot() -> AudioPlaybackState {
        guard let player else { return AudioPlaybackState() }
        player.updateMeters()
        let power = (0..<max(1, player.numberOfChannels)).map { player.averagePower(forChannel: $0) }.max() ?? -160
        let level = player.isPlaying ? min(max((power + 55) / 55, 0), 1) : 0
        return AudioPlaybackState(currentTime: player.currentTime, duration: player.duration, isPlaying: player.isPlaying, level: level)
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.player?.currentTime = 0
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let message = error?.localizedDescription ?? "This audio memo could not be decoded."
        Task { @MainActor [weak self] in
            self?.errorMessage = message
            self?.pause()
        }
    }
}

private enum AudioPlaybackError: LocalizedError {
    case unavailable
    var errorDescription: String? { "This voice memo could not be played. Try loading it again." }
}
#endif
