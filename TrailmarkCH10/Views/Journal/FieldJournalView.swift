import SwiftUI
import TrailMarkCH10Core

struct FieldJournalView: View {
    let viewModel: JournalViewModel
    @State private var showingRecorder = false
    @State private var showingLibrary = false
    var body: some View {
        NavigationStack {
            List {
                if let title = viewModel.activeJourneyTitle {
                    Section {
                        Label("Recording for \(title)", systemImage: "location.fill")
                        Text("New recordings attach to this journey. A recent GPS fix adds their map pins.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("Dismiss message") { viewModel.clearError() }
                    }
                }
                if viewModel.isImporting { ProgressView("Importing video…") }
                if viewModel.items.isEmpty {
                    ContentUnavailableView("No Field Memos", systemImage: "book.closed", description: Text("Record a voice or video memo, or import a video from Photos."))
                } else {
                    Section("Memos") {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                JournalMediaDetailView(viewModel: viewModel.makeDetailViewModel(item: item))
                            } label: { JournalMediaRow(item: item, viewModel: viewModel) }
                        }
                        .onDelete { offsets in
                            let items = offsets.map { viewModel.items[$0] }
                            Task { for item in items { _ = await viewModel.delete(item) } }
                        }
                    }
                }
            }
            .navigationTitle("Field Journal")
            .toolbar {
                Menu {
                    Button("Record a memo", systemImage: "mic.fill") { showingRecorder = true }
                    Button("Import video", systemImage: "photo.on.rectangle") { showingLibrary = true }
                } label: { Label("Add memo", systemImage: "plus") }
                .disabled(viewModel.isImporting)
            }
            .sheet(isPresented: $showingRecorder) { JournalCaptureView(viewModel: viewModel.makeCaptureViewModel()) }
            .sheet(isPresented: $showingLibrary) {
                VideoLibrarySurface(onPicked: { url in
                    showingLibrary = false
                    Task { await viewModel.importVideo(url: url) }
                }, onError: { error in
                    showingLibrary = false
                    viewModel.reportError(error)
                }, onCancel: { showingLibrary = false })
            }
        }
    }
}

struct JournalMediaRow: View {
    let item: JournalMedia
    let viewModel: JournalViewModel
    var body: some View {
        HStack(spacing: 12) {
            MemoThumbnailSurface(data: viewModel.thumbnails[item.id], type: item.type)
                .frame(width: 64, height: 48).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type == .video ? "Video Memo" : "Voice Memo").font(.headline)
                Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                if item.isImported == true { Text("Imported video").font(.caption2).foregroundStyle(.secondary) }
                if item.journeyID != nil {
                    Label(item.coordinate == nil ? "Journey · no location" : "Journey · geotagged", systemImage: "mappin").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.durationText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .task { await viewModel.loadThumbnail(for: item) }
    }
}
