import SwiftUI
import TrailMarkCH10Core

/// One headline and one action. All loading and HealthKit work stays in the shared package.
struct WatchHomeView: View {
    let viewModel: TodayViewModel
    let workoutViewModel: WorkoutViewModel
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 42

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                homeContent
                // Preserve readable text at accessibility sizes; the native scroll view supports the Crown.
                ScrollView { homeContent }
            }
            .navigationTitle("Trailmark")
            .task { await viewModel.refreshToday() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.refreshToday() } }
            }
        }
    }

    private var homeContent: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("TODAY’S STEPS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.stepHeadlineText)
                    .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today’s steps")
            .accessibilityValue(viewModel.stepAccessibilityValue)

            Text(viewModel.stepStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                WatchWorkoutView(viewModel: workoutViewModel)
            } label: {
                Label(workoutViewModel.metrics.isActive ? "Workout Live" : "Start Workout",
                      systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityHint("Opens the walking workout and heart-rate tracker")

            if let explanation = viewModel.stepExplanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Swipe for Memos & Vitals", systemImage: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Swipe for Voice Memos and Live Vitals")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

}
