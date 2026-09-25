import Foundation

/// One completed user action. A fresh ID also distinguishes repeated successes.
public struct UserFeedback: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(_ title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public enum PocketTransferState: String, Codable, Sendable {
    case queued, transferred, failed

    public var label: String {
        switch self {
        case .queued: "Queued for iPhone"
        case .transferred: "Transferred to iPhone"
        case .failed: "Transfer needs a retry"
        }
    }
}
