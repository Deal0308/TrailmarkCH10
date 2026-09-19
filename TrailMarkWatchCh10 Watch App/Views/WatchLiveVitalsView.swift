import SwiftUI
import TrailMarkCH10Core

/// A focused watch dashboard: one dominant value and two compact supporting metrics.
struct WatchLiveVitalsView: View {
    let viewModel: LiveVitalsViewModel
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var heartRateSize: CGFloat = 42

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .navigationTitle("Live Vitals")
            .task {
                if isSelected, scenePhase == .active { await viewModel.start() }
            }
            .onDisappear { viewModel.stop() }
            .onChange(of: scenePhase) { _, _ in synchronizeUpdates() }
            .onChange(of: isSelected) { _, _ in synchronizeUpdates() }
        }
    }

    private var content: some View {
        VStack(spacing: 7) {
            VStack(spacing: 0) {
                Label("HEART RATE", systemImage: "heart.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(viewModel.snapshot.heartRateText)
                        .font(.system(size: heartRateSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)

                Text(viewModel.snapshot.heartRateSampleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heart rate")
            .accessibilityValue(viewModel.snapshot.heartRateAccessibilityValue)

            HStack(spacing: 6) {
                metric(
                    title: "STEPS",
                    value: viewModel.snapshot.stepsText,
                    unit: "today",
                    image: "figure.walk",
                    color: .green,
                    accessibilityValue: viewModel.snapshot.stepsAccessibilityValue
                )
                metric(
                    title: "ENERGY",
                    value: viewModel.snapshot.activeEnergyText,
                    unit: "kcal",
                    image: "flame.fill",
                    color: .orange,
                    accessibilityValue: viewModel.snapshot.activeEnergyAccessibilityValue
                )
            }

            status
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 5)
    }

    private func metric(
        title: String,
        value: String,
        unit: String,
        image: String,
        color: Color,
        accessibilityValue: String
    ) -> some View {
        VStack(spacing: 1) {
            Label(title, systemImage: image)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.capitalized)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.phase == .requestingAuthorization {
            ProgressView(viewModel.statusText)
                .font(.caption2)
        } else if viewModel.phase == .failed {
            VStack(spacing: 4) {
                Text(viewModel.errorMessage ?? viewModel.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.retry() } }
                    .buttonStyle(.bordered)
            }
        } else {
            VStack(spacing: 1) {
                Text(viewModel.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("Retry Updates") { Task { await viewModel.retry() } }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func synchronizeUpdates() {
        if isSelected, scenePhase == .active {
            Task { await viewModel.start() }
        } else {
            viewModel.stop()
        }
    }
}
