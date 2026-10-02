#if os(watchOS)
import HealthKit
import WatchKit

/// Keeps the iPhone-to-watch launch callback inside the shared package.
@MainActor
public final class WorkoutLaunchDelegate: NSObject, WKApplicationDelegate {
    public override init() { super.init() }

    public func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WorkoutLaunchCoordinator.shared.receive(workoutConfiguration)
    }
}

@MainActor
final class WorkoutLaunchCoordinator {
    static let shared = WorkoutLaunchCoordinator()
    private var pending: HKWorkoutConfiguration?
    private var handler: ((HKWorkoutConfiguration) -> Void)?

    func bind(_ handler: @escaping (HKWorkoutConfiguration) -> Void) {
        self.handler = handler
        if let pending {
            self.pending = nil
            handler(pending)
        }
    }

    func receive(_ configuration: HKWorkoutConfiguration) {
        if let handler { handler(configuration) }
        else { pending = configuration }
    }
}
#endif
