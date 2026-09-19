import Foundation

/// Framework-independent values rendered by the memo detail screen.
public struct AudioPlaybackState: Sendable {
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let isPlaying: Bool
    public let level: Float

    public init(currentTime: TimeInterval = 0, duration: TimeInterval = 0, isPlaying: Bool = false, level: Float = 0) {
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.currentTime = currentTime.isFinite ? min(max(0, currentTime), self.duration) : 0
        self.isPlaying = isPlaying
        self.level = level.isFinite ? min(max(0, level), 1) : 0
    }

    public var progress: Double { duration > 0 ? currentTime / duration : 0 }
    public var elapsedText: String { Self.timeText(currentTime) }
    public var remainingText: String { "−" + Self.timeText(duration - currentTime) }

    private static func timeText(_ seconds: TimeInterval) -> String {
        let value = Int(min(seconds, Double(Int.max / 2)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
