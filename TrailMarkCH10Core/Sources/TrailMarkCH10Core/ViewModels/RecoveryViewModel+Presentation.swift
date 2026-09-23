import Foundation

/// Derived recovery values are shared state; the view only lays out and charts them.
public extension RecoveryViewModel {
    var availableEnergyDays: [DailyEnergy] { dailyEnergy.filter(\.hasSamples) }
    var recordedEnergyTotal: Double { availableEnergyDays.reduce(0) { $0 + $1.kilocalories } }
    var energyChartMaximum: Double { max(100, (availableEnergyDays.map(\.kilocalories).max() ?? 0) * 1.15) }
    var energyAccessibilitySummary: String {
        "\(recordedEnergyTotal.formatted(.number.precision(.fractionLength(0)))) kilocalories recorded across \(availableEnergyDays.count) of seven days with available samples. Today is partial. Days without samples are unavailable, not zero."
    }
    var sleepDurationText: String {
        guard let sleepDuration else { return "—" }
        let minutes = max(0, Int((sleepDuration / 60).rounded()))
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    var sleepAccessibilityValue: String {
        guard let sleepDuration else { return "No readable sleep data" }
        let minutes = max(0, Int((sleepDuration / 60).rounded()))
        return "\(minutes / 60) hours and \(minutes % 60) minutes asleep"
    }
}
