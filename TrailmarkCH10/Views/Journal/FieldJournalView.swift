import SwiftUI
import TrailMarkCH10Core

struct FieldJournalView: View {
    let viewModel: JournalViewModel
    @State private var showingRecorder = false
    @State private var showingLibrary = false
    @State private var deletingMemo: JournalMedia?

    var body: some View {
        @Bindable var binding = viewModel
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 22) {
                    TrailmarkSectionHeader(
                        eyebrow: "COLLECT THE MOMENTS",
                        title: "Field journal.",
                        subtitle: "A voice, a view, a moment worth keeping."
                    )
                    if let feedback = viewModel.feedback {
                        TrailmarkFeedback(feedback) { viewModel.dismissFeedback() }
                    }
                    captureCard
                    if let title = viewModel.activeJourneyTitle {
                        VStack(alignment: .leading, spacing: 10) {
                            TrailmarkBadge("ON A JOURNEY", systemImage: "location.fill")
                            Text(title).font(.headline)
                            DisclosureGroup("How your memos connect") {
                                Text("New recordings attach to this journey. A recent GPS fix adds their map pins.")
                                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                            }
                            .font(.subheadline)
                        }
                        .trailmarkCard()
                    }
                    if let error = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            TrailmarkNotice(title: "Your journal needs attention", message: error,
                                            systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                            Button("Dismiss message") { viewModel.clearError() }
                                .buttonStyle(TrailmarkSecondaryButtonStyle())
                        }
                    }
                    if viewModel.isImporting {
                        ProgressView("Bringing your video into the journal…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .trailmarkCard()
                    }
                    if viewModel.items.isEmpty {
                        TrailmarkEmptyState(
                            title: "Every trail has a story.",
                            message: "Your saved voice and video memos will live here. Record your first note or bring in a video from Photos.",
                            systemImage: "book.closed"
                        )
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Your collection").font(.title2.weight(.semibold))
                            Spacer()
                            Text("\(viewModel.items.count) \(viewModel.items.count == 1 ? "memo" : "memos")")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 12, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if !viewModel.items.isEmpty && viewModel.filteredItems.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .listRowBackground(Color.clear)
                }
                ForEach(viewModel.filteredItems) { item in
                    NavigationLink {
                        JournalMediaDetailView(viewModel: viewModel.makeDetailViewModel(item: item))
                    } label: {
                        JournalMediaRow(item: item, viewModel: viewModel)
                    }
                    .trailmarkCard(padding: 16)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .disabled(viewModel.deletingIDs.contains(item.id))
                    .overlay {
                        if viewModel.deletingIDs.contains(item.id) { ProgressView("Deleting…").padding().background(.regularMaterial, in: Capsule()) }
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) { deletingMemo = item }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .trailmarkScreen()
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $binding.searchText, prompt: "Voice, video, watch, or date")
            .sensoryFeedback(.success, trigger: viewModel.feedback?.id) { _, next in next != nil }
            .trailmarkErrorFeedback(viewModel.errorMessage)
            .confirmationDialog("Delete this memo from iPhone?", isPresented: Binding(get: { deletingMemo != nil }, set: { if !$0 { deletingMemo = nil } }), titleVisibility: .visible) {
                if let item = deletingMemo {
                    Button("Delete memo", role: .destructive) {
                        deletingMemo = nil
                        Task { _ = await viewModel.delete(item) }
                    }
                }
                Button("Keep memo", role: .cancel) { deletingMemo = nil }
            } message: {
                Text("This removes the recording and its file from this iPhone. It cannot be undone. A copy on Apple Watch stays there.")
            }
            .toolbar {
                Menu {
                    Button("Record a memo", systemImage: "mic.fill") { showingRecorder = true }
                    Button("Import video", systemImage: "photo.on.rectangle") { showingLibrary = true }
                } label: {
                    Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Add memo")
                .disabled(viewModel.isImporting)
            }
            .sheet(isPresented: $showingRecorder) {
                JournalCaptureView(viewModel: viewModel.makeCaptureViewModel())
            }
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

    private var captureCard: some View {
        TrailmarkHero {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(TrailmarkTheme.lime)
                    .accessibilityHidden(true)
                Text("Keep a little\nof the outside.")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Capture a voice or video memo wherever the day takes you.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Button("Record a memo", systemImage: "record.circle") { showingRecorder = true }
                    .buttonStyle(TrailmarkPrimaryButtonStyle(tint: TrailmarkTheme.lime, foreground: TrailmarkTheme.forest))
                    .disabled(viewModel.isImporting)
                Button("Import from Photos", systemImage: "photo.on.rectangle") { showingLibrary = true }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white)
                    .disabled(viewModel.isImporting)
            }
        }
    }
}

struct JournalMediaRow: View {
    let item: JournalMedia
    let viewModel: JournalViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if item.type == .audio {
                    ZStack {
                        TrailmarkTheme.accent(for: colorScheme).opacity(0.12)
                        Image(systemName: "mic.fill")
                            .font(.title2).foregroundStyle(TrailmarkTheme.accent(for: colorScheme))
                    }
                } else {
                    MemoThumbnailSurface(data: viewModel.thumbnails[item.id], type: item.type)
                        .background(TrailmarkTheme.sky.opacity(0.16))
                }
            }
            .frame(width: 64, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.type == .video ? "Video memo" : "Voice memo")
                    .font(.headline).foregroundStyle(TrailmarkTheme.ink(for: colorScheme))
                Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(item.durationText).monospacedDigit()
                    if item.isWatchMemo { Text("· Apple Watch") }
                    else if item.isImported == true { Text("· Imported") }
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                if item.journeyID != nil {
                    Label(item.coordinate == nil ? "Journey · no location" : "Journey · geotagged", systemImage: "mappin")
                        .font(.caption2).foregroundStyle(TrailmarkTheme.accent(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 72)
        .accessibilityElement(children: .combine)
        .task { await viewModel.loadThumbnail(for: item) }
    }
}
