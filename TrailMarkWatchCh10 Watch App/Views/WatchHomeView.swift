import SwiftUI
import TrailMarkCH10Core

/// One headline and one action; loading and HealthKit remain in the shared package.
struct WatchHomeView: View {
    let viewModel: TodayViewModel
    let workoutViewModel: WorkoutViewModel
    let isHealthEnabled: Bool
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 46

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                homeContent
                ScrollView { homeContent }
            }
            .background(WatchDesign.background)
            .navigationTitle("Trailmark")
            .task(id: isHealthEnabled && isSelected && scenePhase == .active) {
                if isHealthEnabled, isSelected, scenePhase == .active {
                    await viewModel.refreshToday()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var homeContent: some View {
        VStack(spacing: 9) {
            VStack(spacing: 0) {
                WatchEyebrow(title: "Today’s steps", color: WatchDesign.accent)
                Text(isHealthEnabled ? viewModel.stepHeadlineText : "—")
                    .font(.system(size: headlineSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchDesign.foreground)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .background {
                TrailmarkContours()
                    .stroke(WatchDesign.accent.opacity(0.065), lineWidth: 0.75)
                    .clipped()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today’s steps")
            .accessibilityValue(isHealthEnabled ? viewModel.stepAccessibilityValue : "Health not enabled")

            Text(isHealthEnabled ? viewModel.stepStatusText : "Health is optional")
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                WatchWorkoutView(viewModel: workoutViewModel)
            } label: {
                Label(workoutViewModel.metrics.isActive ? "Workout Live" : "Start Workout", systemImage: "figure.walk")
            }
            .buttonStyle(WatchActionStyle())
            .accessibilityHint("Opens the walking workout and heart-rate tracker")

            if isHealthEnabled, let explanation = viewModel.stepExplanation {
                Text(explanation)
                    .font(.caption2)
                    .foregroundStyle(WatchDesign.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(isHealthEnabled ? "Memos · Vitals · Motion" : "Enable Health in Vitals", systemImage: "chevron.down")
                .font(.caption2)
                .foregroundStyle(WatchDesign.muted)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Swipe for Voice Memos, Live Vitals, and Motion. Health can be enabled in Vitals.")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
