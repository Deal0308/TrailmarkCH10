import SwiftUI
import TrailMarkCH10Core

/// Main screen that displays today's HealthKit activity totals.
struct TodayDashboardView: View {
    /// Observable manager that owns HealthKit loading state and activity values.
    let viewModel: TodayViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    metricGrid

                    // Show one of the status panels only when loading, an error, or no data needs explanation.
                    if viewModel.isLoading && !viewModel.hasCompletedInitialLoad {
                        ProgressView("Loading today's health data")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let errorMessage = viewModel.errorMessage {
                        StatePanel(
                            title: "Unable to Load Health Data",
                            message: errorMessage,
                            buttonTitle: "Try Again",
                            systemImage: "exclamationmark.triangle",
                            action: {
                                Task {
                                    await viewModel.retry()
                                }
                            }
                        )
                    } else if viewModel.hasCompletedInitialLoad && !viewModel.hasReadableData {
                        StatePanel(
                            title: "No Health Data",
                            message: "No readable activity or hydration samples are available for today. Data may be missing, still syncing, or not shared; Health does not reveal whether reads were declined.",
                            buttonTitle: "Refresh",
                            systemImage: "heart.text.square",
                            action: {
                                Task {
                                    await viewModel.retry()
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
                await viewModel.loadInitialData()
            }
            .refreshable {
                await viewModel.refreshToday()
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

    /// Two-column metric layout for steps, distance, active energy, and hydration.
    private var metricGrid: some View {
        let summary = viewModel.activitySummary

        return LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize ? [
                GridItem(.flexible())
            ] : [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            MetricCard(
                title: "Steps",
                value: viewModel.metrics?.steps == nil ? "—" : summary.stepsText,
                unit: "steps",
                systemImage: "figure.walk"
            )

            MetricCard(
                title: "Distance",
                value: viewModel.metrics?.distanceMeters == nil ? "—" : summary.distanceText,
                unit: "",
                systemImage: "map"
            )

            MetricCard(
                title: "Active Energy",
                value: viewModel.metrics?.activeEnergyKilocalories == nil ? "—" : summary.activeEnergyText,
                unit: "",
                systemImage: "flame"
            )

            MetricCard(
                title: "Hydration",
                value: viewModel.metrics?.hydrationMilliliters == nil ? "—" : summary.hydrationText,
                unit: "",
                systemImage: "drop.fill"
            )
        }
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
                        .fixedSize(horizontal: false, vertical: true)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
    TodayDashboardView(viewModel: TodayViewModel())
}
