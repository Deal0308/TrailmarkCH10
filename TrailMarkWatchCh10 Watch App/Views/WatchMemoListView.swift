import SwiftUI
import TrailMarkCH10Core

/// Capture comes first; a short, quiet list keeps saved recordings within reach.
struct WatchMemoListView: View {
    let viewModel: WatchMemoViewModel
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 7) {
                        captureControls
                        Text(viewModel.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(WatchDesign.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if viewModel.isRecording {
                            Text("Up to 60 seconds · saves when you leave")
                                .font(.caption2).foregroundStyle(WatchDesign.muted)
                                .multilineTextAlignment(.center)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        VStack(spacing: 8) {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.caption2)
                                .foregroundStyle(WatchDesign.coral)
                            if !viewModel.isStorageAvailable {
                                Button("Retry Storage") { viewModel.retryStorage() }
                                    .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
                            }
                        }
                    }

                    savedMemos
                    if let syncMessage = viewModel.syncMessage {
                        Text(syncMessage).font(.caption2).foregroundStyle(WatchDesign.muted)
                            .multilineTextAlignment(.center)
                        Button("Check Sync", systemImage: "arrow.triangle.2.circlepath") { viewModel.retrySync() }
                            .buttonStyle(WatchActionStyle(prominent: false))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 10)
            }
            .background(WatchDesign.background)
            .navigationTitle("Memos")
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { viewModel.pausePlayback() }
                if phase == .background {
                    Task { await viewModel.leaveCapture() }
                } else if phase == .active {
                    viewModel.reload()
                }
            }
            .onChange(of: isSelected) { _, selected in
                if !selected {
                    Task { await viewModel.leaveCapture() }
                }
            }
            .sensoryFeedback(.start, trigger: viewModel.isRecording) { _, next in next }
            .sensoryFeedback(.success, trigger: viewModel.feedback?.id) { _, next in next != nil }
            .trailmarkErrorFeedback(viewModel.errorMessage)
            .confirmationDialog("Discard this recording?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { viewModel.cancelRecording() }
                Button("Keep Recording", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var captureControls: some View {
        switch viewModel.phase {
        case .recording:
            VStack(spacing: 7) {
                HStack(spacing: 5) {
                    Circle().fill(WatchDesign.coral).frame(width: 6, height: 6)
                    WatchEyebrow(title: "Recording", color: WatchDesign.coral)
                }
                if let start = viewModel.recordingStartedAt {
                    Text(start, style: .timer)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WatchDesign.foreground)
                        .accessibilityLabel("Recording duration")
                }
                Button("Stop & Save", systemImage: "stop.fill") {
                    Task { await viewModel.stopAndSave() }
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))
            }

        case .preparing, .finishing:
            ProgressView(viewModel.phase == .preparing ? "Preparing…" : "Saving…")
                .font(.caption)
                .tint(WatchDesign.coral)
                .frame(maxWidth: .infinity, minHeight: 44)

        case .failed where viewModel.hasPendingCapture:
            VStack(spacing: 6) {
                Button("Retry Save", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retrySaving() }
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))
                Button("Discard", role: .destructive) { confirmingDiscard = true }
                    .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
            }

        default:
            Button("Record Memo", systemImage: "mic.fill") {
                Task { await viewModel.startRecording() }
            }
            .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))
            .accessibilityHint("Starts a voice recording on this Apple Watch")
        }
    }

    private var savedMemos: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                WatchEyebrow(title: "Saved")
                Spacer()
                Text(viewModel.items.count, format: .number)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(WatchDesign.muted)
                    .accessibilityLabel("\(viewModel.items.count) saved memos")
            }
            .padding(.horizontal, 3)

            if viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundStyle(WatchDesign.coral)
                        .accessibilityHidden(true)
                    Text("No memos yet")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(WatchDesign.foreground)
                    Text("Keep a moment from the trail.")
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(WatchDesign.surface, in: RoundedRectangle(cornerRadius: 17))
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            WatchMemoPlaybackView(item: item, viewModel: viewModel)
                        } label: {
                            WatchMemoRow(item: item, syncState: viewModel.transferState(for: item))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRecording || viewModel.isSaving || viewModel.phase == .preparing)
                    }
                }
            }
        }
    }
}

private struct WatchMemoRow: View {
    let item: JournalMedia
    let syncState: PocketTransferState?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.body)
                .foregroundStyle(WatchDesign.coral)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(WatchDesign.foreground)
                HStack(spacing: 5) {
                    Text(item.date, format: .dateTime.hour().minute())
                    Text("·")
                    Text(item.durationText).monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                if let syncState {
                    Text(syncState.label).font(.caption2)
                        .foregroundStyle(syncState == .failed ? WatchDesign.coral : WatchDesign.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchDesign.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        .background(WatchDesign.surface, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice memo, \(item.date.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityValue("\(item.durationText). \(syncState?.label ?? "Saved on this watch")")
    }
}

private struct WatchMemoPlaybackView: View {
    let item: JournalMedia
    let viewModel: WatchMemoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private var isSelected: Bool { viewModel.playingItemID == item.id }
    private var state: AudioPlaybackState {
        isSelected ? viewModel.playbackState : AudioPlaybackState(duration: item.duration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 11) {
                WatchStateSymbol(symbol: "waveform", color: WatchDesign.coral)
                VStack(spacing: 2) {
                    Text(item.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(WatchDesign.foreground)
                    Text(item.date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.muted)
                }

                VStack(spacing: 5) {
                    ProgressView(value: state.progress)
                        .tint(WatchDesign.coral)
                        .accessibilityLabel("Playback progress")
                        .accessibilityValue(state.elapsedText)
                    HStack {
                        Text(state.elapsedText)
                        Spacer()
                        Text(item.durationText)
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(WatchDesign.muted)
                }

                Button(state.isPlaying ? "Pause" : "Play",
                       systemImage: state.isPlaying ? "pause.fill" : "play.fill") {
                    viewModel.togglePlayback(for: item)
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))

                Text(viewModel.transferState(for: item)?.label ?? "Saved on this watch")
                    .font(.caption2).foregroundStyle(WatchDesign.muted)
                    .multilineTextAlignment(.center)
                Button(viewModel.transferState(for: item) == .failed ? "Retry Sync" : viewModel.transferState(for: item) == .transferred ? "Send Again" : "Sync to iPhone", systemImage: "iphone.and.arrow.forward") {
                    viewModel.syncToPhone(item)
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.accent, prominent: false))
                .disabled(viewModel.transferState(for: item) == .queued)
                if viewModel.transferState(for: item) == .queued {
                    Text("Delivery may take time. Your memo is saved on this watch.")
                        .font(.caption2).foregroundStyle(WatchDesign.muted).multilineTextAlignment(.center)
                }

                Button("Delete from Watch", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
                    .disabled(viewModel.deletingIDs.contains(item.id))
                if viewModel.deletingIDs.contains(item.id) { ProgressView("Deleting…") }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(WatchDesign.coral)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .background(WatchDesign.background)
        .navigationTitle("Trail note")
        .task { viewModel.preparePlayback(for: item) }
        .onDisappear { viewModel.pausePlayback() }
        .confirmationDialog("Delete this memo from Apple Watch?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Memo", role: .destructive) {
                Task {
                    await viewModel.delete(item)
                    if !viewModel.items.contains(where: { $0.id == item.id }) { dismiss() }
                }
            }
            Button("Keep Memo", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Copies sent or queued for iPhone stay there.")
        }
    }
}
