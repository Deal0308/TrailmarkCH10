import SwiftUI
import TrailMarkCH10Core

struct WatchWorkoutView: View {
    let viewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("HEART RATE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(viewModel.metrics.currentHeartRateText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.red).monospacedDigit().minimumScaleFactor(0.7)
                HStack {
                    Label(viewModel.metrics.averageHeartRateText, systemImage: "waveform.path.ecg")
                    Spacer()
                    Label(viewModel.metrics.energyText, systemImage: "flame.fill")
                }
                .font(.caption2).foregroundStyle(.secondary)
                elapsed
                if let error = viewModel.errorMessage {
                    Text(error).font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center)
                } else {
                    Text(viewModel.metrics.statusMessage)
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                controls
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Workout")
    }

    @ViewBuilder private var elapsed: some View {
        Text(viewModel.metrics.elapsedText)
            .font(.title3.monospacedDigit())
            .accessibilityLabel("Elapsed time")
            .accessibilityValue(viewModel.metrics.elapsedText)
    }

    @ViewBuilder private var controls: some View {
        switch viewModel.metrics.state {
        case .running, .paused:
            HStack {
                Button { viewModel.pauseOrResume() } label: {
                    Image(systemName: viewModel.metrics.state == .paused ? "play.fill" : "pause.fill")
                }
                .accessibilityLabel(viewModel.metrics.state == .paused ? "Resume workout" : "Pause workout")
                .tint(.blue)
                Button(role: .destructive) { viewModel.end() } label: { Image(systemName: "stop.fill") }
                    .accessibilityLabel("End workout")
                    .tint(.red)
            }
        case .requestingAuthorization, .starting, .ending:
            ProgressView()
        default:
            Button("Start", systemImage: "figure.walk") { Task { await viewModel.start() } }
                .buttonStyle(.borderedProminent).tint(.green)
        }
    }
}
