#if os(iOS)
import AVFoundation
import Foundation
import UIKit

@MainActor
public final class MediaPlaybackService {
    let player = AVPlayer()
    private var statusObservation: NSKeyValueObservation?
    public init() {}

    public func prepare(url: URL, onFailure: @escaping @MainActor @Sendable (String) -> Void) async throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .default)
        try audio.setActive(true)
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else { throw PlaybackError.unplayable }
        try Task.checkCancellation()
        let item = AVPlayerItem(asset: asset)
        statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                let message = item.error?.localizedDescription ?? "Playback failed."
                Task { @MainActor in onFailure(message) }
            }
        }
        player.replaceCurrentItem(with: item)
    }

    public func pause() {
        player.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func stop() {
        pause()
        statusObservation = nil
        player.replaceCurrentItem(with: nil)
    }

    public static func thumbnailData(url: URL) async -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 220)
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.8)
    }

    public static func videoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let seconds = (try await asset.load(.duration)).seconds
        guard !tracks.isEmpty, seconds.isFinite, seconds > 0 else { throw PlaybackError.unplayable }
        return seconds
    }
}

private enum PlaybackError: LocalizedError {
    case unplayable
    var errorDescription: String? { "This media file cannot be played. Try importing a supported video." }
}
#endif
