import Observation
import TrailMarkCH10Core

/// Shared app state for the iOS app.
///
/// `@Observable` lets SwiftUI views update when observable properties change.
@Observable
final class AppModel {
    /// Owns the HealthKit loading logic used by the dashboard UI.
    let healthKitManager = HealthKitManager()
}
