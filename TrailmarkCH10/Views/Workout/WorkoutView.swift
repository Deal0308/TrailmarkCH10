import SwiftUI
import TrailMarkCH10Core

/// A companion to the wrist workout. Shared state remains authoritative for every metric.
struct WorkoutView: View {
    let viewModel: WorkoutViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heartRateSize: CGFloat = 48
    @State private var confirmingEnd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(eyebrow: "WALKING WORKOUT", title: "Find your\nwalking rhythm.", subtitle: "Live from your Apple Watch.")
                    heartRateHero
                    sessionMetrics
                    if let error = viewModel.errorMessage {
                        TrailmarkNotice(title: "Your watch needs attention", message: error, systemImage: "applewatch", tint: TrailmarkTheme.clay)
                    }
                    DisclosureGroup {
                        Text("Apple Watch measures your heart rate and shares the workout here. Trailmark shows the latest reported sample with its measurement time; iPhone does not estimate BPM. A finished workout is saved to Apple Health. If the connection drops, the watch keeps control of the session.")
                            .font(.footnote)
                            .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                            .padding(.top, 10)
                    } label: {
                        Label("How watch workouts work", systemImage: "applewatch")
                            .font(.subheadline.weight(.medium))
                    }
                    .trailmarkCard()
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .trailmarkScreen()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controls
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .background(TrailmarkTheme.background(for: scheme))
                    .overlay(alignment: .top) {
                        Rectangle().fill(TrailmarkTheme.line(for: scheme)).frame(height: 0.5)
                    }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Finish this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("Finish & save workout") { viewModel.end() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Apple Watch will end this session and save it to Health.")
            }
            .sensoryFeedback(.success, trigger: viewModel.metrics.state) { _, next in next == .completed }
            .trailmarkErrorFeedback(viewModel.errorMessage)
        }
    }

    private var heartRateHero: some View {
        TrailmarkHero {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack { heartRateLabel; Spacer(); stateBadge }
                    VStack(alignment: .leading, spacing: 12) { heartRateLabel; stateBadge }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.metrics.currentHeartRateText)
                        .font(.system(size: heartRateSize, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    if let date = viewModel.metrics.heartRateSampleDate {
                        Text("Measured \(date.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(TrailmarkTheme.cream)
                    } else {
                        Text("Wrist readings appear during your workout.")
                            .font(.subheadline).foregroundStyle(TrailmarkTheme.cream)
                    }
                }
                .accessibilityElement(children: .combine)
                Text(viewModel.metrics.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(TrailmarkTheme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var heartRateLabel: some View {
        Label("HEART RATE", systemImage: "heart")
            .font(.caption.weight(.semibold))
            .tracking(1.5)
    }

    private var stateBadge: some View {
        TrailmarkBadge(stateTitle, systemImage: statusIcon, tint: TrailmarkTheme.lime)
    }

    private var sessionMetrics: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(TrailmarkTheme.accent(for: scheme))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Elapsed time").font(.subheadline)
                        .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    Text(viewModel.metrics.elapsedText)
                        .font(.system(.largeTitle, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .trailmarkCard()
            .accessibilityElement(children: .combine)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                      ? [GridItem(.flexible())]
                      : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                TrailmarkMetricTile(title: "Average heart rate", value: viewModel.metrics.averageHeartRateText, systemImage: "waveform.path.ecg", tint: TrailmarkTheme.clay)
                TrailmarkMetricTile(title: "Workout energy", value: viewModel.metrics.energyText, systemImage: "flame", tint: TrailmarkTheme.gold)
            }
        }
    }

    @ViewBuilder private var controls: some View {
        if viewModel.isSendingCommand {
            ProgressView("Waiting for Apple Watch…").frame(maxWidth: .infinity, minHeight: 52)
        } else if viewModel.metrics.state == .running || viewModel.metrics.state == .paused {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { activeControls }
            } else {
                HStack(spacing: 10) { activeControls }
            }
        } else {
            Button {
                Task { await viewModel.start() }
            } label: {
                if isTransitioning {
                    HStack {
                        ProgressView().tint(scheme == .dark ? TrailmarkTheme.forest : .white)
                        Text(stateTitle)
                    }
                } else {
                    Label(viewModel.metrics.state == .completed ? "Start another walk" : "Start on Apple Watch", systemImage: "applewatch")
                }
            }
            .buttonStyle(TrailmarkPrimaryButtonStyle())
            .disabled(isTransitioning)
        }
    }

    @ViewBuilder private var activeControls: some View {
        Button(viewModel.metrics.state == .paused ? "Resume" : "Pause",
               systemImage: viewModel.metrics.state == .paused ? "play.fill" : "pause.fill") {
            viewModel.pauseOrResume()
        }
        .buttonStyle(TrailmarkPrimaryButtonStyle())
        Button("End workout", systemImage: "stop.fill", role: .destructive) { confirmingEnd = true }
            .buttonStyle(TrailmarkSecondaryButtonStyle())
    }

    private var isTransitioning: Bool {
        viewModel.metrics.state == .requestingAuthorization || viewModel.metrics.state == .starting || viewModel.metrics.state == .ending
    }
    private var stateTitle: String {
        switch viewModel.metrics.state {
        case .idle: "Ready"
        case .requestingAuthorization: "Health access"
        case .starting: "Connecting"
        case .running: "In progress"
        case .paused: "Paused"
        case .ending: "Finishing"
        case .completed: "Complete"
        case .failed: "Unavailable"
        }
    }
    private var statusIcon: String {
        switch viewModel.metrics.state {
        case .running: "figure.walk"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        default: "applewatch"
        }
    }
}
