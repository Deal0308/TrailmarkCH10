import Foundation
import Testing
@testable import TrailMarkCH10Core

struct WorkoutMetricsTests {
    @Test
    func workoutMetricsStoreAndFormatHeartRate() {
        let start = Date(timeIntervalSince1970: 1_000)
        let metrics = WorkoutMetrics(
            state: .running,
            startedAt: start,
            elapsedTime: 125,
            currentHeartRateBPM: 143.6,
            averageHeartRateBPM: 137.2,
            activeEnergyKilocalories: 42.7,
            statusMessage: "Tracking"
        )

        #expect(metrics.state == .running)
        #expect(metrics.startedAt == start)
        #expect(metrics.currentHeartRateBPM == 143.6)
        #expect(metrics.averageHeartRateBPM == 137.2)
        #expect(metrics.currentHeartRateText == "144 BPM")
        #expect(metrics.averageHeartRateText == "137 BPM")
        #expect(metrics.energyText == "43 kcal")
        #expect(metrics.elapsedText == "02:05")
        #expect(metrics.isActive)
    }

    @Test
    func invalidSensorValuesRemainUnavailable() {
        let metrics = WorkoutMetrics(
            state: .running,
            elapsedTime: -.infinity,
            currentHeartRateBPM: .nan,
            averageHeartRateBPM: -20,
            activeEnergyKilocalories: -.infinity
        )

        #expect(metrics.elapsedTime == 0)
        #expect(metrics.currentHeartRateBPM == nil)
        #expect(metrics.averageHeartRateBPM == nil)
        #expect(metrics.activeEnergyKilocalories == nil)
        #expect(metrics.currentHeartRateText == "— BPM")
    }

    @Test
    func workoutMetricsRoundTripForPhoneMirroring() throws {
        let original = WorkoutMetrics(
            state: .paused,
            startedAt: Date(timeIntervalSince1970: 2_000),
            elapsedTime: 90,
            currentHeartRateBPM: 121,
            averageHeartRateBPM: 118,
            activeEnergyKilocalories: 12,
            statusMessage: "Paused"
        )
        let decoded = try JSONDecoder().decode(WorkoutMetrics.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(decoded.isActive)
    }
}
