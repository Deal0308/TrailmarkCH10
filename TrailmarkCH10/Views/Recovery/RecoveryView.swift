import Charts
import SwiftUI
import TrailMarkCH10Core

/// Recovery queries and derived values belong to the package; this screen presents them.
struct RecoveryView: View {
    let viewModel: RecoveryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @State private var showingHelp = false
    @State private var confirmingSample = false
    @ScaledMetric(relativeTo: .largeTitle) private var sleepSize: CGFloat = 48

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(eyebrow: "REST & RHYTHM", title: "Rest is part\nof the journey.", subtitle: "A little perspective on sleep and movement.")
                    if let error = viewModel.authorizationErrorMessage { errorNotice(error) }
                    sleepCard
                    energyCard
                    sampleWorkoutCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .trailmarkScreen()
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await viewModel.refresh() } }
                        .disabled(viewModel.isLoading)
                }
            }
            .task { await viewModel.load() }
            .sensoryFeedback(.success, trigger: viewModel.savedWorkout?.id) { _, next in next != nil }
            .sheet(isPresented: $showingHelp) { TrailmarkHelpView() }
            .trailmarkErrorFeedback(viewModel.authorizationErrorMessage ?? viewModel.sleepErrorMessage ?? viewModel.energyErrorMessage ?? viewModel.workoutErrorMessage)
            .confirmationDialog("Add sample data to Apple Health?", isPresented: $confirmingSample, titleVisibility: .visible) {
                Button("Save synthetic sample") { Task { await viewModel.saveSampleWorkout() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This adds a demonstration walk with 120 kcal, 1.5 km, and 128 BPM. These are sample values and will affect your Health totals.")
            }
            .refreshable { await viewModel.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && viewModel.hasLoaded { Task { await viewModel.refresh() } }
            }
        }
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrailmarkHero {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("LAST NIGHT").font(.caption.weight(.semibold)).tracking(1.5)
                        Spacer()
                        Image(systemName: "moon.stars").font(.title2.weight(.light)).foregroundStyle(TrailmarkTheme.lime).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.isLoading ? "—" : viewModel.sleepDurationText)
                            .font(.system(size: sleepSize, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("Time asleep").font(.subheadline).foregroundStyle(TrailmarkTheme.cream)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Last night’s sleep")
                    .accessibilityValue(viewModel.isLoading ? "Loading" : viewModel.sleepAccessibilityValue)
                    if !viewModel.hasLoaded || viewModel.isLoading {
                        ProgressView("Reading sleep…").tint(TrailmarkTheme.lime).font(.caption)
                    } else {
                        Text(viewModel.sleepDuration == nil ? "Your sleep story is still to come." : "Rest, recorded in Apple Health.")
                            .font(.caption)
                            .foregroundStyle(TrailmarkTheme.cream)
                    }
                }
            }
            if let error = viewModel.sleepErrorMessage { errorNotice(error) }
            else if viewModel.hasLoaded && !viewModel.isLoading && viewModel.sleepDuration == nil {
                Text("No readable sleep samples yet. They may still be syncing, unrecorded, or not shared.")
                    .font(.footnote)
                    .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                Button("Health & permission help", systemImage: "questionmark.circle") { showingHelp = true }
                    .buttonStyle(TrailmarkSecondaryButtonStyle())
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(dateAndTime(viewModel.windows.sleepStart)) → \(dateAndTime(viewModel.windows.sleepEnd))")
                        .font(.subheadline.weight(.medium))
                    Text("Local time · \(TimeZone.current.identifier). From 6 p.m. yesterday to noon today, capped at the latest refresh time.")
                    Text("Includes Core, Deep, REM, and unspecified sleep. Awake and in-bed-only samples are excluded. Overlapping intervals count once and are clipped to this window.")
                    Text("Health keeps read-permission choices private. Missing samples do not establish that access was denied.")
                }
                .font(.footnote)
                .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                .padding(.top, 12)
            } label: {
                Label("How sleep is measured", systemImage: "moon.zzz")
                    .font(.subheadline.weight(.medium))
            }
            .trailmarkCard(padding: 18)
        }
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) { energyHeading; Spacer(); TrailmarkBadge("7 DAYS", tint: scheme == .dark ? TrailmarkTheme.lime : TrailmarkTheme.clay) }
                VStack(alignment: .leading, spacing: 10) { TrailmarkBadge("7 DAYS"); energyHeading }
            }
            if !viewModel.hasLoaded || viewModel.isLoading {
                ProgressView("Reading active energy…").frame(maxWidth: .infinity, minHeight: 200)
            } else if let error = viewModel.energyErrorMessage {
                errorNotice(error)
            } else {
                if viewModel.availableEnergyDays.isEmpty {
                    Text("No recorded energy yet")
                        .font(.subheadline.weight(.medium))
                    Text("Your week will take shape as samples arrive.")
                        .font(.footnote).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(viewModel.recordedEnergyTotal.formatted(.number.precision(.fractionLength(0)))) kcal")
                            .font(.system(.title, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("Recorded across \(viewModel.availableEnergyDays.count) of 7 days")
                            .font(.caption).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    }
                }
                energyChart
                Text("Today is still in progress. Gaps mean no readable samples; a dot at zero is a recorded zero.")
                    .font(.caption)
                    .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                DisclosureGroup("Daily values & details") {
                    VStack(spacing: 14) {
                        ForEach(viewModel.dailyEnergy) { day in dailyEnergyRow(day) }
                        Text("Active energy only; resting energy is excluded. Today includes data through \(viewModel.windows.energyEnd.formatted(date: .omitted, time: .shortened)).")
                            .font(.caption)
                            .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 12)
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .trailmarkCard()
    }

    private var energyHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your week in motion")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text("\(shortDate(viewModel.windows.energyStart)) – \(shortDate(viewModel.windows.energyEnd)) · active energy")
                .font(.caption)
                .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
        }
    }

    private var energyChart: some View {
        Chart {
            ForEach(viewModel.availableEnergyDays) { day in
                if day.kilocalories == 0 {
                    PointMark(x: .value("Date", chartDateLabel(day.date)), y: .value("Active energy (kcal)", 0))
                        .foregroundStyle(scheme == .dark ? TrailmarkTheme.lime : TrailmarkTheme.forest)
                        .symbolSize(32)
                } else {
                    BarMark(x: .value("Date", chartDateLabel(day.date)), y: .value("Active energy (kcal)", day.kilocalories), width: .ratio(0.52))
                        .foregroundStyle((scheme == .dark ? TrailmarkTheme.lime : TrailmarkTheme.forest).gradient)
                        .cornerRadius(5)
                }
            }
        }
        .chartXScale(domain: viewModel.dailyEnergy.map { chartDateLabel($0.date) })
        .chartYScale(domain: 0...viewModel.energyChartMaximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(TrailmarkTheme.line(for: scheme))
                AxisValueLabel().foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
            }
        }
        .chartXAxis {
            AxisMarks(values: viewModel.dailyEnergy.map { chartDateLabel($0.date) }) { value in
                AxisValueLabel {
                    if let label = value.as(String.self), let date = viewModel.dailyEnergy.first(where: { chartDateLabel($0.date) == label })?.date {
                        VStack(spacing: 3) {
                            Text(date.formatted(.dateTime.weekday(.narrow))).fontWeight(.semibold)
                            Text(label)
                        }
                        .font(.caption2)
                        .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    }
                }
            }
        }
        .frame(height: 210)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active energy for the last seven calendar days")
        .accessibilityValue(viewModel.energyAccessibilitySummary)
        .accessibilityHint("Expand Daily values and details for each date and its energy.")
    }

    private func dailyEnergyRow(_ day: DailyEnergy) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { Text(dailyDateLabel(day)); Spacer(); Text(energyValue(day)).monospacedDigit() }
            VStack(alignment: .leading, spacing: 3) { Text(dailyDateLabel(day)); Text(energyValue(day)).monospacedDigit() }
        }
        .font(.subheadline)
        .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(energyValue(day))
    }

    private var sampleWorkoutCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                TrailmarkBadge("SYNTHETIC SAMPLE", systemImage: "info.circle", tint: scheme == .dark ? TrailmarkTheme.lime : TrailmarkTheme.clay)
                Text("20-minute indoor walk").font(.headline)
                Text("120 kcal · 1.5 km · 128 BPM average").font(.subheadline)
                Text("For the course demonstration. Saving adds these synthetic values to Apple Health and can affect your Health totals.")
                    .font(.footnote).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                Button {
                    confirmingSample = true
                } label: {
                    if viewModel.isSavingWorkout {
                        HStack { ProgressView(); Text("Saving to Health…") }
                    } else if viewModel.savedWorkout != nil {
                        Label("Sample saved", systemImage: "checkmark.circle")
                    } else {
                        Label("Save sample to Health", systemImage: "heart")
                    }
                }
                .buttonStyle(TrailmarkPrimaryButtonStyle())
                .disabled(viewModel.isSavingWorkout || viewModel.savedWorkout != nil)
                if let error = viewModel.workoutErrorMessage {
                    TrailmarkNotice(title: "Sample couldn’t be saved", message: error, systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                }
                if let status = viewModel.workoutStatusMessage { Text(status).font(.footnote) }
                if let receipt = viewModel.savedWorkout {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Saved workout").font(.subheadline.weight(.semibold))
                        Text("\(dateAndTime(receipt.startDate)) → \(dateAndTime(receipt.endDate))")
                        Text("\(Int((receipt.duration / 60).rounded())) min · \(receipt.energyKilocalories.formatted(.number.precision(.fractionLength(0)))) kcal · \((receipt.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(1)))) km · \(receipt.averageHeartRateBPM.formatted(.number.precision(.fractionLength(0)))) BPM")
                    }.font(.footnote)
                }
                Divider()
                Text("Verify in Apple Health").font(.subheadline.weight(.semibold))
                Text("Open Health → Search (or Browse) → Activity → Workouts → Show All Data. Find the saved walk by date and time, and check its duration and source. Record that screen for the assignment; a successful save alone is not visual verification.")
                    .font(.footnote).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
            }.padding(.top, 16)
        } label: {
            Label("Sample workout", systemImage: "figure.walk.circle")
                .font(.subheadline.weight(.semibold))
        }
        .trailmarkCard()
    }

    private func errorNotice(_ error: String) -> some View {
        VStack(spacing: 10) {
            TrailmarkNotice(title: "Health needs a moment", message: error, systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
            Button("Retry Health data", systemImage: "arrow.clockwise") { Task { await viewModel.refresh() } }
                .buttonStyle(TrailmarkSecondaryButtonStyle())
                .disabled(viewModel.isLoading)
        }
    }
    private func energyValue(_ day: DailyEnergy) -> String {
        day.hasSamples ? "\(day.kilocalories.formatted(.number.precision(.fractionLength(0)))) kcal" : "Unavailable"
    }
    private func dailyDateLabel(_ day: DailyEnergy) -> String {
        let label = day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return Calendar.current.isDate(day.date, inSameDayAs: viewModel.windows.energyEnd) ? "\(label) · Today" : label
    }
    private func dateAndTime(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()) }
    private func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }
    private func chartDateLabel(_ date: Date) -> String { date.formatted(.dateTime.month(.defaultDigits).day()) }
}
