import SwiftUI
import TrailMarkCH10Core

struct JournalCaptureView: View {
    @State var viewModel: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingCancel = false
    var body: some View {
        @Bindable var binding = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Memo type", selection: $binding.type) {
                        Text("Voice Memo").tag(JournalMediaType.audio)
                        Text("Video Memo").tag(JournalMediaType.video)
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.phase != .idle && viewModel.phase != .failed)
                    if viewModel.type == .video {
                        CameraPreviewSurface(service: viewModel.service).frame(height: 280).background(.black).clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityHidden(true)
                        Text("Videos stop automatically after 2 minutes.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "waveform.circle.fill").font(.system(size: 84)).foregroundStyle(.blue).frame(height: 200)
                            .accessibilityHidden(true)
                    }
                    Text(viewModel.associationMessage).font(.footnote).foregroundStyle(.secondary)
                    if let date = viewModel.startedAt, viewModel.phase == .recording {
                        Text(date, style: .timer).font(.title.monospacedDigit())
                    }
                    if let error = viewModel.errorMessage { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.footnote) }
                    switch viewModel.phase {
                    case .idle, .failed:
                        Button("Record", systemImage: "record.circle") { Task { await viewModel.record() } }.buttonStyle(.borderedProminent)
                    case .recording:
                        Button("Stop and save", systemImage: "stop.fill") { viewModel.stop() }.buttonStyle(.borderedProminent).tint(.red)
                    case .preparing: ProgressView("Preparing recording…")
                    case .finishing: ProgressView("Finishing recording…")
                    case .finished:
                        if viewModel.isSaving { ProgressView("Saving memo…") }
                        else if !viewModel.saved { Button("Retry saving") { Task { await viewModel.save() } } }
                    }
                }.padding()
            }
            .navigationTitle("New Field Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if viewModel.phase == .idle || viewModel.phase == .failed { dismiss() }
                    else { confirmingCancel = true }
                }.disabled(viewModel.isSaving)
            } }
            .confirmationDialog("Discard this unsaved recording?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) { viewModel.cancel(); dismiss() }
            }
            .interactiveDismissDisabled(viewModel.phase != .idle && !viewModel.saved)
            .onChange(of: viewModel.saved) { _, saved in if saved { dismiss() } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { viewModel.suspend() } }
            .onDisappear { viewModel.cancel() }
        }
    }
}
