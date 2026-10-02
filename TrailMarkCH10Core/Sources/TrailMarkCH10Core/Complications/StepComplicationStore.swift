import Foundation
#if os(watchOS) && canImport(WidgetKit)
import WidgetKit
#endif

/// A small, read-only-to-the-widget snapshot. The watch app is the only writer.
public struct StepComplicationSnapshot: Codable, Equatable, Sendable {
    public let steps: Int
    public let measuredAt: Date

    public init?(steps: Double, measuredAt: Date) {
        guard steps.isFinite, steps >= 0, steps < Double(Int.max) else { return nil }
        self.steps = Int(steps.rounded())
        self.measuredAt = measuredAt
    }
}

/// App Group storage shared by the watch app and its WidgetKit extension.
/// It never requests Health access; unavailable or yesterday's data stays unavailable.
public struct StepComplicationStore: Sendable {
    public static let appGroupIdentifier = "group.com.example.TrailmarkCH10"
    public static let widgetKind = "TrailmarkTodaySteps"
    private static let snapshotKey = "todayStepsSnapshot.v1"

    public init() {}

    public func read(now: Date = .now, calendar: Calendar = .current) -> StepComplicationSnapshot? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(StepComplicationSnapshot.self, from: data),
              calendar.isDate(snapshot.measuredAt, inSameDayAs: now) else { return nil }
        return snapshot
    }

    @discardableResult
    public func save(steps: Double, measuredAt: Date) -> Bool {
        guard let snapshot = StepComplicationSnapshot(steps: steps, measuredAt: measuredAt),
              let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = try? JSONEncoder().encode(snapshot) else { return false }
        // Frequent live-vitals callbacks should not ask WidgetKit to reload an
        // unchanged value. Refresh an unchanged reading at most every 15 minutes.
        if let previous = read(now: measuredAt) {
            guard measuredAt >= previous.measuredAt else { return true }
            if previous.steps == snapshot.steps,
               measuredAt.timeIntervalSince(previous.measuredAt) < 15 * 60 { return true }
        }
        defaults.set(data, forKey: Self.snapshotKey)
        #if os(watchOS) && canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        #endif
        return true
    }

    public func clear() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        defaults.removeObject(forKey: Self.snapshotKey)
        #if os(watchOS) && canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        #endif
    }
}
