import Foundation

/// Keeps sensor APIs out of the view model and permits another platform adapter.
@MainActor
public protocol MotionProviding: AnyObject {
    var availability: MotionAvailability { get }
    var onSnapshot: (@MainActor @Sendable (MotionSnapshot) -> Void)? { get set }
    var onError: (@MainActor @Sendable (String) -> Void)? { get set }
    func start() throws
    func stop()
}
