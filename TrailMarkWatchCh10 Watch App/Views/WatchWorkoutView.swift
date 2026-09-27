import SwiftUI
import TrailMarkCH10Core

/// Live workout controls render the shared workout model without owning sensors.
struct WatchWorkoutView: View {
    let viewModel: WorkoutViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

                if let receipt = viewModel.metrics.savedWorkout {
                    savedWorkoutCard(receipt)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 6) { liveMetricCards }
                } else {
                    HStack(alignment: .top, spacing: 6) { liveMetricCards }
                }

                if let date = viewModel.metrics.heartRateSampleDate {
                    Text("Heart rate measured \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.muted)
                        .multilineTextAlignment(.center)
                } else if viewModel.metrics.state == .running || viewModel.metrics.state == .paused {
                    Text("No heart-rate sample yet")
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.muted)
                        .multilineTextAlignment(.center)
                }

                controls

                runtimeNote

                if viewModel.metrics.state == .completed {
                    WatchMetricCard(
                        title: "Average heart rate",
                        value: viewModel.metrics.averageHeartRateText,
                        symbol: "heart",
                        color: WatchDesign.coral,
                        accessibilityValue: viewModel.metrics.averageHeartRateText
                    )
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

    @ViewBuilder private var liveMetricCards: some View {
        WatchMetricCard(
            title: "Heart rate",
            value: viewModel.metrics.currentHeartRateText,
            symbol: "heart.fill",
            color: WatchDesign.coral,
            accessibilityValue: viewModel.metrics.currentHeartRateText
        )
        WatchMetricCard(
            title: "Energy",
            value: viewModel.metrics.energyText,
            symbol: "flame.fill",
            color: WatchDesign.gold,
            accessibilityValue: viewModel.metrics.energyText
        )
    }

    @ViewBuilder private var runtimeNote: some View {
        if viewModel.metrics.state == .running {
            Label("Keep walking. Recording continues with your wrist down or another app open.", systemImage: "figure.walk")
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
                .fixedSize(horizontal: false, vertical: true)
        } else if viewModel.metrics.state == .paused {
            Text("Paused time does not count toward your walking time. Resume when you’re ready.")
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func savedWorkoutCard(_ receipt: WorkoutSaveReceipt) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Saved to Health", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(WatchDesign.accent)
            Text(receipt.dateText)
                .font(.caption2)
                .foregroundStyle(WatchDesign.foreground)
            Text("Walking time · \(receipt.durationText)")
                .font(.caption2)
                .foregroundStyle(WatchDesign.foreground)
            Text(receipt.confirmationText)
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
            NavigationLink {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Find your walk", systemImage: "heart.text.clipboard")
                            .font(.headline)
                            .foregroundStyle(WatchDesign.accent)
                        Text(viewModel.healthVerificationInstructions)
                            .font(.footnote)
                            .foregroundStyle(WatchDesign.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .background(WatchDesign.background)
                .navigationTitle("Health")
            } label: {
                Text("Find it in Health")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchDesign.accent)
            }
            .buttonStyle(WatchActionStyle(prominent: false))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WatchDesign.surface, in: RoundedRectangle(cornerRadius: 15))
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
        case .confirmationUnavailable: "Check Health"
        case .requestingAuthorization, .starting: "Getting ready"
        case .failed: "Workout"
        case .idle: "Ready to walk"
        }
    }
}
