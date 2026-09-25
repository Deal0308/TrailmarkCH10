import SwiftUI
import TrailMarkCH10Core

/// Health is a focused, optional page. Authorization never blocks the other pages.
struct WatchLiveVitalsView: View {
    let viewModel: LiveVitalsViewModel
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heartRateSize: CGFloat = 42

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .background(WatchDesign.background)
            .navigationTitle("Vitals")
            .onAppear { synchronizeUpdates() }
            .onDisappear { viewModel.setActive(false) }
            .onChange(of: scenePhase) { _, _ in synchronizeUpdates() }
            .onChange(of: isSelected) { _, _ in synchronizeUpdates() }
        }
        .preferredColorScheme(.dark)
        .trailmarkErrorFeedback(viewModel.errorMessage)
    }

    private var content: some View {
        VStack(spacing: 9) {
            if let reason = viewModel.unavailableReason {
                WatchStateSymbol(symbol: "applewatch", color: WatchDesign.coral)
                Text("Vitals on your watch")
                    .font(.system(.headline, design: .rounded))
                explanation(reason)
            } else if viewModel.phase == .requestingAuthorization {
                WatchStateSymbol(symbol: "heart.fill", color: WatchDesign.coral)
                ProgressView("Requesting Health access")
                    .font(.caption2)
                    .tint(WatchDesign.coral)
                Button("Not Now") { viewModel.continueWithoutHealth() }
                    .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
            } else if viewModel.phase == .failed {
                WatchStateSymbol(symbol: "heart.slash", color: WatchDesign.coral)
                Text("Health needs attention")
                    .font(.system(.headline, design: .rounded))
                    .multilineTextAlignment(.center)
                Button("Try Again", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retry() }
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))
                explanation(viewModel.errorMessage ?? viewModel.statusText)
                Button("Use Without Health") { viewModel.continueWithoutHealth() }
                    .buttonStyle(WatchActionStyle(tint: WatchDesign.muted, prominent: false))
            } else if !viewModel.isHealthEnabled {
                WatchStateSymbol(symbol: "heart.fill", color: WatchDesign.coral)
                Text("Your live vitals")
                    .font(.system(.headline, design: .rounded))
                Button("Enable Health", systemImage: "heart") {
                    Task { await viewModel.enableHealth() }
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral))
                explanation("Heart rate, steps & energy.\nOptional, whenever you’re ready.")
            } else {
                measurements
            }
        }
        .foregroundStyle(WatchDesign.foreground)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var measurements: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                WatchEyebrow(title: "Heart rate", color: WatchDesign.coral)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(viewModel.displayedSnapshot.heartRateText)
                        .font(.system(size: heartRateSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchDesign.foreground)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WatchDesign.muted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)

                Text(viewModel.displayedSnapshot.heartRateSampleDate == nil
                     ? "No readable heart-rate sample"
                     : viewModel.displayedSnapshot.heartRateSampleText)
                    .font(.caption2)
                    .foregroundStyle(WatchDesign.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heart rate")
            .accessibilityValue(viewModel.displayedSnapshot.heartRateAccessibilityValue)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 6) { dailyMetricCards }
            } else {
                HStack(spacing: 6) { dailyMetricCards }
            }

            VStack(spacing: 2) {
                Text(viewModel.heartRateSourceText)
                    .font(.caption2.weight(.medium))
                Text(viewModel.statusText)
                    .font(.caption2)
            }
            .foregroundStyle(WatchDesign.muted)
            .multilineTextAlignment(.center)

            if let workout = viewModel.workoutViewModel {
                NavigationLink {
                    WatchWorkoutView(viewModel: workout)
                } label: {
                    Label(workout.metrics.isActive ? "Workout Controls" : "Walking Workout", systemImage: "figure.walk")
                }
                .buttonStyle(WatchActionStyle(prominent: false))
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(WatchDesign.coral)
                    .multilineTextAlignment(.center)
                Button("Retry Updates", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retry() }
                }
                .buttonStyle(WatchActionStyle(tint: WatchDesign.coral, prominent: false))
            }
        }
    }

    @ViewBuilder private var dailyMetricCards: some View {
        WatchMetricCard(
            title: "Steps",
            value: viewModel.snapshot.stepsText,
            symbol: "figure.walk",
            color: WatchDesign.accent,
            accessibilityValue: viewModel.snapshot.stepsAccessibilityValue
        )
        WatchMetricCard(
            title: "kcal",
            value: viewModel.snapshot.activeEnergyText,
            symbol: "flame.fill",
            color: WatchDesign.gold,
            accessibilityValue: viewModel.snapshot.activeEnergyAccessibilityValue
        )
    }

    private func explanation(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(WatchDesign.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func synchronizeUpdates() {
        viewModel.setActive(isSelected && scenePhase == .active)
    }
}
