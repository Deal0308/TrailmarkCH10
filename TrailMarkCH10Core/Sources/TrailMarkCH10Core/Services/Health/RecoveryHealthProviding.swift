import Foundation

/// Injectable package boundary: tests exercise screen state without accessing personal Health data.
@MainActor
public protocol RecoveryHealthProviding {
    func requestReadAuthorization() async throws
    func readSleep(in window: DateInterval) async throws -> TimeInterval?
    func readEnergy(windows: RecoveryDateWindows, calendar: Calendar) async throws -> [DailyEnergy]
    func saveSampleWorkout(_ activity: SampleWorkoutActivity) async throws -> SampleWorkoutReceipt
}
