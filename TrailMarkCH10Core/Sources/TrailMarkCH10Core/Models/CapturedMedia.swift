import Foundation

/// Shared recorder state used by the media service and capture view model.
public enum CapturePhase: Equatable, Sendable {
    case idle, preparing, recording, finishing, finished, failed
}

public struct CapturedMedia: Sendable {
    public let url: URL
    public let duration: TimeInterval
    public let type: JournalMediaType
}
