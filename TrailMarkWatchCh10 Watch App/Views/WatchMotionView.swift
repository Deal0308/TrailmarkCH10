import SwiftUI
import TrailMarkCH10Core

/// One measured signal and one explicit action; no decorative sensor readings.
struct WatchMotionView: View {
    let viewModel: MotionViewModel
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 42

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .background(WatchDesign.background)
            .navigationTitle("Motion")
            .onDisappear { viewModel.stop() }
            .onChange(of: isSelected) { _, selected in
                if !selected { viewModel.stop() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { viewModel.stop() }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.start, trigger: viewModel.isRunning) { _, next in next }
        .sensoryFeedback(.stop, trigger: viewModel.isRunning) { previous, next in previous && !next }
    }

    private var content: some View {
        VStack(spacing: 9) {
            if viewModel.availability == .available {
                measurement
                Button {
                    if viewModel.isRunning { viewModel.stop() }
                    else if isSelected, scenePhase == .active { viewModel.start() }
                } label: {
                    Label(
                        viewModel.isRunning ? "Stop" : (viewModel.phase == .failed ? "Try Again" : "Start Sensing"),
                        systemImage: viewModel.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(WatchActionStyle(tint: viewModel.isRunning ? WatchDesign.coral : WatchDesign.accent))
            } else {
                WatchStateSymbol(symbol: "applewatch")
                Text("A feel for motion")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(WatchDesign.foreground)
            }

            Text(viewModel.statusText)
                .font(.caption2)
                .foregroundStyle(viewModel.phase == .failed ? WatchDesign.coral : WatchDesign.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.availability == .available {
                Text("Stops when you leave")
                    .font(.caption2)
                    .foregroundStyle(WatchDesign.muted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var measurement: some View {
        VStack(spacing: 0) {
            WatchEyebrow(title: viewModel.movementText, color: WatchDesign.accent)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(viewModel.accelerationText)
                    .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchDesign.foreground)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("g").font(.caption).foregroundStyle(WatchDesign.muted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            Text(viewModel.snapshot == nil || viewModel.isRunning ? "Movement intensity" : "Last measurement")
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion")
        .accessibilityValue(viewModel.accessibilityValue)
    }
}
