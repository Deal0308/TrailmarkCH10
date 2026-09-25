import SwiftUI
import TrailMarkCH10Core

struct JournalMediaDetailView: View {
    @State var viewModel: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TrailmarkSectionHeader(
                    eyebrow: "FROM YOUR FIELD JOURNAL",
                    title: viewModel.item.type == .video ? "A view to revisit." : "A moment, replayed.",
                    subtitle: viewModel.item.date.formatted(date: .long, time: .shortened)
                )
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { memoBadges }
                    VStack(alignment: .leading, spacing: 8) { memoBadges }
                }

                if viewModel.isReady {
                    if viewModel.item.type == .audio {
                        audioControls
                    } else {
                        MediaPlayerSurface(service: viewModel.playback)
                            .frame(height: 300)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                } else if let error = viewModel.errorMessage {
                    TrailmarkEmptyState(title: "Playback unavailable.", message: error, systemImage: "play.slash")
                    Button("Retry playback", systemImage: "arrow.clockwise") { Task { await viewModel.load() } }
                        .buttonStyle(TrailmarkPrimaryButtonStyle())
                } else {
                    ProgressView("Preparing your memo…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .trailmarkCard()
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("The details").font(.title3.weight(.semibold))
                    if viewModel.item.isWatchMemo {
                        Label("Recorded on Apple Watch", systemImage: "applewatch")
                            .font(.subheadline)
                        Text("Date shown is when you recorded it. This copy is saved on your iPhone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if viewModel.item.isImported == true {
                        Label("Imported from your library", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                        Text("Date shown is the import date. This clip has no inferred capture location.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let point = viewModel.item.coordinate {
                        Label("Geotagged at recording start", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                        DisclosureGroup("Location details") {
                            Text("\(point.latitude.formatted(.number.precision(.fractionLength(5)))), \(point.longitude.formatted(.number.precision(.fractionLength(5)))) · ±\(Int(point.horizontalAccuracy)) m")
                                .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                        }
                        .font(.subheadline)
                    } else {
                        Label("No capture location", systemImage: "location.slash")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if viewModel.item.journeyID != nil {
                            Text("This memo is part of a journey, without a map pin.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .trailmarkCard()

                if viewModel.isReady, let error = viewModel.errorMessage {
                    TrailmarkNotice(title: "Memo update", message: error,
                                    systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .trailmarkScreen()
        .navigationTitle("Field memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                .frame(minHeight: 44)
                .disabled(viewModel.isDeleting)
        }
        .confirmationDialog("Delete this memo and its file?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete memo", role: .destructive) { Task { await viewModel.delete() } }
            Button("Keep memo", role: .cancel) {}
        } message: {
            Text("This cannot be undone. A copy already saved on Apple Watch stays there.")
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isDeleting { ProgressView("Deleting memo…").frame(maxWidth: .infinity).padding().background(.regularMaterial) }
        }
        .trailmarkErrorFeedback(viewModel.errorMessage)
        .task { await viewModel.load() }
        .onChange(of: viewModel.deleted) { _, deleted in if deleted { dismiss() } }
        .onDisappear { viewModel.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.pause() } }
    }

    @ViewBuilder
    private var memoBadges: some View {
        TrailmarkBadge(viewModel.item.type == .video ? "VIDEO MEMO" : "VOICE MEMO",
                       systemImage: viewModel.item.type == .video ? "video.fill" : "mic.fill")
        TrailmarkBadge(viewModel.item.durationText, systemImage: "clock", tint: TrailmarkTheme.clay)
    }

    private var audioControls: some View {
        VStack(spacing: 20) {
            HStack {
                Label("LISTEN BACK", systemImage: "headphones")
                    .font(.caption.weight(.semibold)).tracking(1.2)
                Spacer()
                Text(viewModel.audioState.isPlaying ? "Playing" : "Ready")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !viewModel.waveform.isEmpty {
                AudioWaveformView(samples: viewModel.waveform, progress: viewModel.audioState.progress,
                                  level: viewModel.audioState.level, isPlaying: viewModel.audioState.isPlaying,
                                  onSeek: { viewModel.seekAudio(to: $0) })
                    .frame(height: 104)
            } else if viewModel.isLoadingWaveform {
                ProgressView("Loading waveform…").frame(height: 104)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "mic.fill").font(.system(size: 40, weight: .light))
                        .foregroundStyle(TrailmarkTheme.accent(for: colorScheme))
                        .accessibilityHidden(true)
                    Text("Audio ready · waveform unavailable")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: 104)
            }
            VStack(spacing: 4) {
                Slider(value: Binding(get: { viewModel.audioState.progress }, set: { viewModel.seekAudio(to: $0) }), in: 0...1)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Playback position")
                    .accessibilityValue(viewModel.audioState.elapsedText)
                HStack {
                    Text(viewModel.audioState.elapsedText)
                    Spacer()
                    Text(viewModel.audioState.remainingText)
                }
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Button(action: { viewModel.toggleAudioPlayback() }) {
                Label(viewModel.audioState.isPlaying ? "Pause" : "Play memo",
                      systemImage: viewModel.audioState.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(TrailmarkPrimaryButtonStyle())
        }
        .trailmarkCard(padding: 24)
    }
}
