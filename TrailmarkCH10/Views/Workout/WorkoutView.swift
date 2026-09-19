import SwiftUI
import TrailMarkCH10Core

/// Companion workout screen. Apple Watch supplies live sensor data through HealthKit mirroring.
struct WorkoutView: View {
    let viewModel: WorkoutViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Walking workout").font(.title2.bold())
                        Text("Heart rate is measured by Apple Watch and mirrored here while the workout runs.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            metricCard("Heart Rate", value: viewModel.metrics.currentHeartRateText, icon: "heart.fill", tint: .red)
                            metricCard("Average", value: viewModel.metrics.averageHeartRateText, icon: "waveform.path.ecg", tint: .pink)
                        }
                        VStack(spacing: 12) {
                            metricCard("Heart Rate", value: viewModel.metrics.currentHeartRateText, icon: "heart.fill", tint: .red)
                            metricCard("Average", value: viewModel.metrics.averageHeartRateText, icon: "waveform.path.ecg", tint: .pink)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            metricCard("Elapsed", value: viewModel.metrics.elapsedText, icon: "timer", tint: .blue)
                            metricCard("Energy", value: viewModel.metrics.energyText, icon: "flame.fill", tint: .orange)
                        }
                        VStack(spacing: 12) {
                            metricCard("Elapsed", value: viewModel.metrics.elapsedText, icon: "timer", tint: .blue)
                            metricCard("Energy", value: viewModel.metrics.energyText, icon: "flame.fill", tint: .orange)
                        }
                    }

                    Label(viewModel.metrics.statusMessage, systemImage: statusIcon)
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                    }
                    controls
                    Text("The iPhone does not estimate BPM. A paired Apple Watch starts the HealthKit workout and provides its real heart-rate samples. The completed workout is saved to Health.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout")
        }
    }

    private var controls: some View {
        HStack {
            if viewModel.metrics.state == .running || viewModel.metrics.state == .paused {
                Button(viewModel.metrics.state == .paused ? "Resume" : "Pause",
                       systemImage: viewModel.metrics.state == .paused ? "play.fill" : "pause.fill") {
                    viewModel.pauseOrResume()
                }
                .buttonStyle(.bordered)
                Button("End", systemImage: "stop.fill", role: .destructive) { viewModel.end() }
                    .buttonStyle(.borderedProminent).tint(.red)
            } else {
                Button("Start on Apple Watch", systemImage: "applewatch") {
                    Task { await viewModel.start() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.metrics.state == .requestingAuthorization ||
                          viewModel.metrics.state == .starting || viewModel.metrics.state == .ending)
            }
        }
    }

    private func metricCard(_ title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(tint)
            Text(value).font(.title3.bold()).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: String {
        switch viewModel.metrics.state {
        case .running: "heart.circle.fill"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "applewatch"
        }
    }
}
