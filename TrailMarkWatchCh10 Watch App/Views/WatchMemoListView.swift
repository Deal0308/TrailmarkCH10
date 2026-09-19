import SwiftUI
import TrailMarkCH10Core

/// A watch-first capture surface: one record control followed by short saved memos.
struct WatchMemoListView: View {
    let viewModel: WatchMemoViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    captureControls
                    Text(viewModel.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        if !viewModel.isStorageAvailable {
                            Button("Retry storage") { viewModel.retryStorage() }
                        }
                    }
                }

                Section("Saved") {
                    if viewModel.items.isEmpty {
                        Label("No voice memos yet", systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                WatchMemoPlaybackView(item: item, viewModel: viewModel)
                            } label: {
                                WatchMemoRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Voice Memos")
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, viewModel.isRecording {
                    Task { await viewModel.stopAndSave() }
                } else if phase == .active {
                    viewModel.reload()
                }
            }
        }
    }

    @ViewBuilder private var captureControls: some View {
        switch viewModel.phase {
        case .recording:
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)
                if let start = viewModel.recordingStartedAt {
                    Text(start, style: .timer)
                        .font(.title2.monospacedDigit())
                        .accessibilityLabel("Recording duration")
                }
                Button("Stop & Save", systemImage: "stop.fill") {
                    Task { await viewModel.stopAndSave() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .frame(maxWidth: .infinity)

        case .preparing, .finishing:
            ProgressView(viewModel.phase == .preparing ? "Preparing…" : "Saving…")
                .frame(maxWidth: .infinity)

        case .failed where viewModel.hasPendingCapture:
            VStack(spacing: 6) {
                Button("Retry Save", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retrySaving() }
                }
                .buttonStyle(.borderedProminent)
                Button("Discard", role: .destructive) { viewModel.cancelRecording() }
                    .font(.caption)
            }

        default:
            Button("Record Memo", systemImage: "mic.fill") {
                Task { await viewModel.startRecording() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Starts a voice recording on this Apple Watch")
        }
    }
}

private struct WatchMemoRow: View {
    let item: JournalMedia

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .lineLimit(1)
                Text(item.durationText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice memo, \(item.date.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityValue(item.durationText)
    }
}

private struct WatchMemoPlaybackView: View {
    let item: JournalMedia
    let viewModel: WatchMemoViewModel

    private var isSelected: Bool { viewModel.playingItemID == item.id }
    private var state: AudioPlaybackState {
        isSelected ? viewModel.playbackState : AudioPlaybackState(duration: item.duration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .multilineTextAlignment(.center)

                ProgressView(value: state.progress)
                    .accessibilityLabel("Playback progress")
                    .accessibilityValue(state.elapsedText)
                HStack {
                    Text(state.elapsedText)
                    Spacer()
                    Text(item.durationText)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

                Button(state.isPlaying ? "Pause" : "Play",
                       systemImage: state.isPlaying ? "pause.fill" : "play.fill") {
                    viewModel.togglePlayback(for: item)
                }
                .buttonStyle(.borderedProminent)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Memo")
        .task { viewModel.preparePlayback(for: item) }
        .onDisappear { viewModel.pausePlayback() }
    }
}
