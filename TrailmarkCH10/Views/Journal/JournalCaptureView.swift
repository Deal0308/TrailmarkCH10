import SwiftUI
import TrailMarkCH10Core

struct JournalCaptureView: View {
    @State var viewModel: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingCancel = false
    @State private var showingHelp = false

    var body: some View {
        @Bindable var binding = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(
                        eyebrow: "A MOMENT TO KEEP",
                        title: viewModel.type == .audio ? "In your own words." : "Take in the view.",
                        subtitle: "A small memory of wherever you are."
                    )
                    Picker("Memo type", selection: $binding.type) {
                        Text("Voice").tag(JournalMediaType.audio)
                        Text("Video").tag(JournalMediaType.video)
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.phase != .idle && viewModel.phase != .failed)

                    if viewModel.type == .video {
                        VStack(alignment: .leading, spacing: 12) {
                            CameraPreviewSurface(service: viewModel.service)
                                .frame(height: 300)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .accessibilityHidden(true)
                            Label("Up to 2 minutes", systemImage: "clock")
                                .font(.caption).foregroundStyle(.secondary)
                            if viewModel.phase == .idle {
                                Text("Your camera opens when you start recording.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        TrailmarkHero {
                            VStack(spacing: 22) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 56, weight: .light))
                                    .foregroundStyle(TrailmarkTheme.lime)
                                    .accessibilityHidden(true)
                                Text(viewModel.phase == .recording ? "Listening to your story." : "Make a little room\nfor a memory.")
                                    .font(.system(.title, design: .serif, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let date = viewModel.startedAt, viewModel.phase == .recording {
                                    Text(date, style: .timer)
                                        .font(.system(.largeTitle, design: .rounded, weight: .medium))
                                        .monospacedDigit()
                                        .accessibilityLabel("Recording duration")
                                } else {
                                    Text(recordingPrompt)
                                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }

                    if viewModel.type == .video, let date = viewModel.startedAt, viewModel.phase == .recording {
                        HStack {
                            TrailmarkBadge("RECORDING", systemImage: "record.circle", tint: TrailmarkTheme.clay)
                            Spacer()
                            Text(date, style: .timer).font(.title2.monospacedDigit())
                        }
                    }
                    if let error = viewModel.errorMessage {
                        TrailmarkNotice(title: "Let's keep your memo safe", message: error,
                                        systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                        Button("Recording & permission help", systemImage: "questionmark.circle") { showingHelp = true }
                            .buttonStyle(TrailmarkSecondaryButtonStyle())
                    }
                    DisclosureGroup("Journey & recording details") {
                        Text(viewModel.associationMessage)
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    }
                    .font(.subheadline.weight(.medium))
                    .trailmarkCard()
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) { recordingAction }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(TrailmarkTheme.background(for: colorScheme))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(TrailmarkTheme.line(for: colorScheme))
                            .frame(height: 1)
                    }
            }
            .trailmarkScreen()
            .navigationTitle("New memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.phase == .idle || viewModel.phase == .failed { dismiss() }
                        else { confirmingCancel = true }
                    }
                    .frame(minHeight: 44)
                    .disabled(viewModel.isSaving)
                }
            }
            .confirmationDialog("Discard this unsaved recording?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) { viewModel.cancel(); dismiss() }
                Button("Keep recording", role: .cancel) {}
            }
            .interactiveDismissDisabled(viewModel.phase != .idle && !viewModel.saved)
            .onChange(of: viewModel.saved) { _, saved in if saved { dismiss() } }
            .trailmarkErrorFeedback(viewModel.errorMessage)
            .onChange(of: scenePhase) { _, phase in if phase == .background { viewModel.suspend() } }
            .onDisappear { viewModel.cancel() }
            .sheet(isPresented: $showingHelp) { TrailmarkHelpView() }
        }
    }

    @ViewBuilder
    private var recordingAction: some View {
        switch viewModel.phase {
        case .idle, .failed:
            Button("Record", systemImage: "record.circle") { Task { await viewModel.record() } }
                .buttonStyle(TrailmarkPrimaryButtonStyle())
        case .recording:
            Button("Stop & save", systemImage: "stop.fill") { viewModel.stop() }
                .buttonStyle(TrailmarkPrimaryButtonStyle(tint: TrailmarkTheme.clay, foreground: .white))
        case .preparing:
            ProgressView("Preparing recording…").frame(maxWidth: .infinity, minHeight: 52)
        case .finishing:
            ProgressView("Finishing recording…").frame(maxWidth: .infinity, minHeight: 52)
        case .finished:
            if viewModel.isSaving {
                ProgressView("Saving your memo…").frame(maxWidth: .infinity, minHeight: 52)
            } else if !viewModel.saved {
                Button("Retry saving", systemImage: "arrow.clockwise") { Task { await viewModel.save() } }
                    .buttonStyle(TrailmarkPrimaryButtonStyle())
            }
        }
    }

    private var recordingPrompt: String {
        switch viewModel.phase {
        case .idle, .failed: "Tap Record when you're ready."
        case .preparing: "Getting your microphone ready."
        case .recording: "Recording your voice."
        case .finishing: "Finishing your recording."
        case .finished: viewModel.isSaving ? "Saving your memory." : "Your recording is ready to save."
        }
    }
}
