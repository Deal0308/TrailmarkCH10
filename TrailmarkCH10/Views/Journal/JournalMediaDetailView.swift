import SwiftUI
import TrailMarkCH10Core

struct JournalMediaDetailView: View {
    @State var viewModel: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingDelete = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isReady {
                    if viewModel.item.type == .audio { audioControls }
                    else { MediaPlayerSurface(service: viewModel.playback).frame(height: 300) }
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Playback unavailable", systemImage: "play.slash", description: Text(error))
                    Button("Retry playback") { Task { await viewModel.load() } }
                } else { ProgressView("Preparing playback…").frame(height: 250) }
                Text(viewModel.item.type == .video ? "Video Memo" : "Voice Memo").font(.title2.bold())
                Text("\(viewModel.item.date.formatted(date: .abbreviated, time: .shortened)) · \(viewModel.item.durationText)")
                if viewModel.item.isImported == true { Text("Date shown is the import date. This clip has no inferred capture location.").font(.footnote).foregroundStyle(.secondary) }
                if let point = viewModel.item.coordinate {
                    Label("Geotagged at recording start", systemImage: "mappin.and.ellipse")
                    Text("\(point.latitude.formatted(.number.precision(.fractionLength(5)))), \(point.longitude.formatted(.number.precision(.fractionLength(5)))) · ±\(Int(point.horizontalAccuracy)) m").font(.footnote).foregroundStyle(.secondary)
                } else { Text("No capture location is stored for this memo.").font(.footnote).foregroundStyle(.secondary) }
                if viewModel.isReady, let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
            }.padding()
        }
        .navigationTitle("Field Memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }.disabled(viewModel.isDeleting) }
        .confirmationDialog("Delete this memo and its file?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete memo", role: .destructive) { Task { await viewModel.delete() } }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.deleted) { _, deleted in if deleted { dismiss() } }
        .onDisappear { viewModel.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.pause() } }
    }

    private var audioControls: some View {
        VStack(spacing: 16) {
            if !viewModel.waveform.isEmpty {
                AudioWaveformView(samples: viewModel.waveform, progress: viewModel.audioState.progress,
                                  level: viewModel.audioState.level, isPlaying: viewModel.audioState.isPlaying,
                                  onSeek: { viewModel.seekAudio(to: $0) })
                    .frame(height: 88)
            } else if viewModel.isLoadingWaveform {
                ProgressView("Loading waveform…").frame(height: 88)
            } else {
                Image(systemName: "waveform").font(.system(size: 54)).foregroundStyle(.blue).frame(height: 88)
            }
            Slider(value: Binding(get: { viewModel.audioState.progress }, set: { viewModel.seekAudio(to: $0) }), in: 0...1)
                .accessibilityLabel("Playback position")
                .accessibilityValue(viewModel.audioState.elapsedText)
            HStack {
                Text(viewModel.audioState.elapsedText)
                Spacer()
                Text(viewModel.audioState.remainingText)
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Button(action: { viewModel.toggleAudioPlayback() }) {
                Label(viewModel.audioState.isPlaying ? "Pause" : "Play",
                      systemImage: viewModel.audioState.isPlaying ? "pause.fill" : "play.fill")
            }.buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
