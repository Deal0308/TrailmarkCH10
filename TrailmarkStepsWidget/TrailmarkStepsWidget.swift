import SwiftUI
import WidgetKit
import TrailMarkCH10Core

private struct StepEntry: TimelineEntry {
    let date: Date
    let snapshot: StepComplicationSnapshot?
}

private struct StepProvider: TimelineProvider {
    private let store = StepComplicationStore()

    func placeholder(in context: Context) -> StepEntry {
        StepEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        completion(StepEntry(date: .now, snapshot: store.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let now = Date()
        let entry = StepEntry(date: now, snapshot: store.read(now: now))
        // Request a new entry around midnight even if the watch app stays closed.
        let nextDay = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(1800)
        let refresh = min(now.addingTimeInterval(1800), nextDay)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

private struct StepWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .medium))
                    Text(stepText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            default:
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TODAY’S STEPS")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(stepText)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(entry.snapshot?.measuredAt.formatted(date: .omitted, time: .shortened) ?? "Open app")
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .widgetAccentable()
        .containerBackground(.clear, for: .widget)
        .accessibilityLabel(entry.snapshot.map { "\($0.steps) steps today, updated \($0.measuredAt.formatted(date: .omitted, time: .shortened))" } ?? "Today's steps unavailable. Open Trailmark and enable Health in Vitals.")
    }

    private var stepText: String {
        entry.snapshot?.steps.formatted() ?? "—"
    }
}

private struct TrailmarkStepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StepComplicationStore.widgetKind, provider: StepProvider()) { entry in
            StepWidgetView(entry: entry)
        }
        .configurationDisplayName("Trailmark Steps")
        .description("Today’s steps from Trailmark on your Apple Watch.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

@main
struct TrailmarkStepsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrailmarkStepsWidget()
    }
}
