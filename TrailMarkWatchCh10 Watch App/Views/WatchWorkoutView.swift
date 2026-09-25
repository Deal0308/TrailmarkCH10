import SwiftUI
import TrailMarkCH10Core

/// Live workout controls render the shared workout model without owning sensors.
struct WatchWorkoutView: View {
    let viewModel: WorkoutViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heartRateSize: CGFloat = 36
    @State private var confirmingEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 1) {
                    WatchEyebrow(title: workoutStateTitle, color: WatchDesign.accent)
                    Text(viewModel.metrics.elapsedText)
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WatchDesign.foreground)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(viewModel.metrics.elapsedText)
                }

                VStack(spacing: 2) {
                    Label("Heart rate", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.coral)
                    Text(viewModel.metrics.currentHeartRateText)
                        .font(.system(size: heartRateSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchDesign.foreground)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .contentTransition(.numericText())
                    if let date = viewModel.metrics.heartRateSampleDate {
                        Text("Measured \(date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(WatchDesign.muted)
                    } else {
                        Text("No heart-rate sample")
                            .font(.caption2)
                            .foregroundStyle(WatchDesign.muted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(WatchDesign.surface, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityElement(children: .combine)

                controls

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 6) { workoutMetricCards }
                } else {
                    HStack(spacing: 6) { workoutMetricCards }
                }

                Text(viewModel.errorMessage ?? viewModel.metrics.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(viewModel.errorMessage == nil ? WatchDesign.muted : WatchDesign.coral)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let syncMessage = viewModel.pocketSyncMessage {
                    Label(syncMessage, systemImage: "iphone.and.arrow.forward")
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.accent)
                        .multilineTextAlignment(.center)
                    Button("Check Sync", systemImage: "arrow.triangle.2.circlepath") { viewModel.retrySync() }
                        .buttonStyle(WatchActionStyle(prominent: false))
                }
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 10)
        }
        .background(WatchDesign.background)
        .navigationTitle("Walking")
        .preferredColorScheme(.dark)
        .confirmationDialog("Finish this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("Finish & Save") { viewModel.end() }
            Button("Keep Going", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: viewModel.metrics.state) { _, next in next == .completed }
        .trailmarkErrorFeedback(viewModel.errorMessage)
    }

    @ViewBuilder private var controls: some View {
        switch viewModel.metrics.state {
        case .running, .paused:
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 7) { activeWorkoutButtons }
            } else {
                HStack(spacing: 7) { activeWorkoutButtons }
            }
        case .requestingAuthorization, .starting, .ending:
            ProgressView(viewModel.metrics.state == .ending ? "Saving workout…" : "Preparing workout…")
                .font(.caption2)
                .tint(WatchDesign.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
        default:
            Button("Start Walk", systemImage: "figure.walk") {
                Task { await viewModel.start() }
            }
            .buttonStyle(WatchActionStyle())
        }
    }

    @ViewBuilder private var workoutMetricCards: some View {
        WatchMetricCard(
            title: "Average",
            value: viewModel.metrics.averageHeartRateText,
            symbol: "heart",
            color: WatchDesign.coral,
            accessibilityValue: viewModel.metrics.averageHeartRateText
        )
        WatchMetricCard(
            title: "Energy",
            value: viewModel.metrics.energyText,
            symbol: "flame.fill",
            color: WatchDesign.gold,
            accessibilityValue: viewModel.metrics.energyText
        )
    }

    @ViewBuilder private var activeWorkoutButtons: some View {
        Button { viewModel.pauseOrResume() } label: {
            VStack(spacing: 3) {
                Image(systemName: viewModel.metrics.state == .paused ? "play.fill" : "pause.fill")
                Text(viewModel.metrics.state == .paused ? "Resume" : "Pause")
                    .font(.caption2.weight(.semibold))
            }
        }
        .buttonStyle(WatchActionStyle())
        .accessibilityLabel(viewModel.metrics.state == .paused ? "Resume workout" : "Pause workout")

        Button(role: .destructive) { confirmingEnd = true } label: {
            VStack(spacing: 3) {
                Image(systemName: "stop.fill")
                Text("End").font(.caption2.weight(.semibold))
            }
        }
        .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
        .accessibilityLabel("End workout")
    }

    private var workoutStateTitle: String {
        switch viewModel.metrics.state {
        case .running: "Workout live"
        case .paused: "Paused"
        case .ending: "Saving"
        case .completed: "Workout saved"
        case .requestingAuthorization, .starting: "Getting ready"
        case .failed: "Workout"
        case .idle: "Ready to walk"
        }
    }
}
