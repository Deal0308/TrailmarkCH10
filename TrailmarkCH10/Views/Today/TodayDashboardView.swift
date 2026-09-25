import SwiftUI
import TrailMarkCH10Core

/// A daily overview; the shared view model owns Health access and data loading.
struct TodayDashboardView: View {
    let viewModel: TodayViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingHelp = false
    @ScaledMetric(relativeTo: .largeTitle) private var stepSize: CGFloat = 58

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(
                        eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                        title: "A little further,\nevery day.",
                        subtitle: "Your movement, one day at a time."
                    )
                    stepsHero
                    essentials
                    healthState
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.clipboard")
                        Text("Your day, brought together with Apple Health.")
                    }
                    .font(.caption)
                    .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .trailmarkScreen()
            .navigationTitle("Trailmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Trailmark help", systemImage: "questionmark.circle") { showingHelp = true }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh Health", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refreshToday() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task { await viewModel.loadInitialData() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.loadInitialData() } }
            }
            .sheet(isPresented: $showingHelp) { TrailmarkHelpView() }
            .trailmarkErrorFeedback(viewModel.errorMessage)
            .refreshable { await viewModel.refreshToday() }
        }
    }

    private var stepsHero: some View {
        TrailmarkHero {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label("TODAY’S STEPS", systemImage: "figure.walk")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                    Spacer(minLength: 8)
                    Image(systemName: "sun.max")
                        .font(.title3.weight(.light))
                        .foregroundStyle(TrailmarkTheme.lime)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.metrics?.steps == nil ? "—" : viewModel.activitySummary.stepsText)
                        .font(.system(size: stepSize, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(viewModel.metrics?.steps == nil ? "Room for your next step." : "Every step belongs to your story.")
                        .font(.subheadline)
                        .foregroundStyle(TrailmarkTheme.cream)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today’s steps")
                .accessibilityValue(viewModel.metrics?.steps == nil ? "Unavailable" : viewModel.activitySummary.stepsText)
                HStack(spacing: 6) {
                    Circle().fill(TrailmarkTheme.lime).frame(width: 5, height: 5).accessibilityHidden(true)
                    Text(heroStatus)
                        .font(.caption)
                        .foregroundStyle(TrailmarkTheme.cream)
                }
            }
        }
    }

    private var essentials: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily essentials")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("TODAY").font(.caption2.weight(.semibold)).tracking(1.5)
                    .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
            }
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                      ? [GridItem(.flexible())]
                      : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                TrailmarkMetricTile(
                    title: "Distance",
                    value: viewModel.metrics?.distanceMeters == nil ? "—" : viewModel.activitySummary.distanceText,
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    tint: TrailmarkTheme.forest
                )
                TrailmarkMetricTile(
                    title: "Active energy",
                    value: viewModel.metrics?.activeEnergyKilocalories == nil ? "—" : viewModel.activitySummary.activeEnergyText,
                    systemImage: "flame",
                    tint: TrailmarkTheme.clay
                )
            }
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundStyle(scheme == .dark ? TrailmarkTheme.cream : TrailmarkTheme.sky)
                    .frame(width: 46, height: 52)
                    .background(TrailmarkTheme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Hydration").font(.subheadline.weight(.semibold))
                    Text("Water logged in Health")
                        .font(.caption)
                        .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    if dynamicTypeSize.isAccessibilitySize { hydrationValue }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 6)
                    hydrationValue
                }
            }
            .trailmarkCard()
            .accessibilityElement(children: .combine)
        }
    }

    private var hydrationValue: some View {
        Text(viewModel.metrics?.hydrationMilliliters == nil ? "—" : viewModel.activitySummary.hydrationText)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var healthState: some View {
        if viewModel.isLoading {
            ProgressView(viewModel.hasCompletedInitialLoad ? "Refreshing your day…" : "Bringing your day together…")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .trailmarkCard()
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                TrailmarkNotice(title: "Health is taking a moment", message: error, systemImage: "heart.slash", tint: TrailmarkTheme.clay)
                Button("Try again", systemImage: "arrow.clockwise") { Task { await viewModel.retry() } }
                    .buttonStyle(TrailmarkSecondaryButtonStyle())
                if viewModel.showingPreviousReadings { Text("Showing the last available readings for today.").font(.caption).foregroundStyle(.secondary) }
            }
        } else if viewModel.hasCompletedInitialLoad && !viewModel.hasReadableData {
            VStack(alignment: .leading, spacing: 14) {
                TrailmarkNotice(
                    title: "A fresh page",
                    message: "Your measurements appear here when they’re recorded and shared through Apple Health.",
                    systemImage: "leaf"
                )
                DisclosureGroup("About missing measurements") {
                    Text("A dash means no readable data. Samples may still be syncing, may not have been recorded, or may not be shared with Trailmark. Health keeps read-permission choices private.")
                        .font(.footnote)
                        .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                        .padding(.top, 8)
                }
                .font(.footnote.weight(.medium))
                Button("Health & permission help", systemImage: "questionmark.circle") { showingHelp = true }
                    .buttonStyle(TrailmarkSecondaryButtonStyle())
            }
        }
    }

    private var heroStatus: String {
        if viewModel.isLoading { return "Reading Apple Health…" }
        if let date = viewModel.metrics?.queriedAt {
            return "\(viewModel.showingPreviousReadings ? "Last successful read" : "Updated") \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Measurements appear when available"
    }
}
