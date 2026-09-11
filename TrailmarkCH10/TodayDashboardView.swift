import SwiftUI
import TrailMarkCH10Core

/// Main screen that displays today's HealthKit activity totals.
struct TodayDashboardView: View {
    /// Observable manager that owns HealthKit loading state and activity values.
    let healthKitManager: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    metricGrid

                    // Show one of the status panels only when loading, an error, or no data needs explanation.
                    if healthKitManager.isLoading && !healthKitManager.hasCompletedInitialLoad {
                        ProgressView("Loading today's activity")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let errorMessage = healthKitManager.errorMessage {
                        StatePanel(
                            title: "Unable to Load Activity",
                            message: errorMessage,
                            buttonTitle: "Try Again",
                            systemImage: "exclamationmark.triangle",
                            action: {
                                Task {
                                    await healthKitManager.retry()
                                }
                            }
                        )
                    } else if healthKitManager.hasCompletedInitialLoad && !healthKitManager.activitySummary.hasActivityData {
                        StatePanel(
                            title: "No Activity Data",
                            message: "TrailMark doesn't have activity data available for today. Make sure Health access is enabled and activity data exists in the Health app.",
                            buttonTitle: "Refresh",
                            systemImage: "heart.text.square",
                            action: {
                                Task {
                                    await healthKitManager.retry()
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .task {
                await healthKitManager.loadInitialData()
            }
            .refreshable {
                await healthKitManager.refreshToday()
            }
        }
    }

    /// Header text showing the current day.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    /// Two-column metric layout for steps, distance, and active energy.
    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            MetricCard(
                title: "Steps",
                value: stepsText,
                unit: "steps",
                systemImage: "figure.walk"
            )

            MetricCard(
                title: "Distance",
                value: distanceText,
                unit: distanceUnitText,
                systemImage: "map"
            )

            MetricCard(
                title: "Active Energy",
                value: activeEnergyText,
                unit: "kcal",
                systemImage: "flame"
            )
            .gridCellColumns(2)
        }
    }

    /// Formats the integer step count with the user's locale separators.
    private var stepsText: String {
        healthKitManager.activitySummary.steps.formatted(.number)
    }

    /// Converts stored meters into miles before display.
    private var distanceMeasurement: Measurement<UnitLength> {
        Measurement(
            value: healthKitManager.activitySummary.distanceMeters,
            unit: UnitLength.meters
        ).converted(to: .miles)
    }

    /// Shows distance with one decimal place.
    private var distanceText: String {
        distanceMeasurement.value.formatted(.number.precision(.fractionLength(1)))
    }

    /// Unit label for the converted distance value.
    private var distanceUnitText: String {
        "mi"
    }

    /// Rounds active energy to a whole kilocalorie value for a cleaner dashboard.
    private var activeEnergyText: String {
        healthKitManager.activitySummary.activeEnergyKilocalories
            .rounded()
            .formatted(.number.precision(.fractionLength(0)))
    }
}

/// Reusable card for showing one activity metric.
private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Reusable panel for loading problems and empty-data messages.
private struct StatePanel: View {
    let title: String
    let message: String
    let buttonTitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: action) {
                Label(buttonTitle, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    TodayDashboardView(healthKitManager: HealthKitManager())
}
