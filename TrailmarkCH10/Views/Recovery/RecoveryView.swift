import Charts
import SwiftUI
import TrailMarkCH10Core

/// Presents the shared package's recovery queries and explicit sample-workout write action.
struct RecoveryView: View {
    let viewModel: RecoveryViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let message = viewModel.authorizationErrorMessage {
                        errorNotice(message)
                    }

                    sleepCard
                    energyCard
                    workoutCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recovery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
            .onChange(of: scenePhase) { _, phase in
                // Requery after the user changes permissions or checks the sample in Health.
                if phase == .active && viewModel.hasLoaded {
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep and active energy")
                .font(.title2.weight(.semibold))
            Text("Your recent sleep and movement from Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.isLoading && viewModel.hasLoaded {
                ProgressView("Refreshing Health data…")
                    .font(.footnote)
            }
        }
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Last night's sleep", systemImage: "moon.zzz.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if !viewModel.hasLoaded || viewModel.isLoading {
                loadingPlaceholder("Loading sleep…")
            } else if let message = viewModel.sleepErrorMessage {
                errorNotice(message)
            } else if let duration = viewModel.sleepDuration {
                Text(durationText(duration))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityLabel("Asleep for \(spokenDuration(duration))")
            } else {
                Text("No sleep samples available")
                    .font(.title3.weight(.semibold))
                Text("Sleep may not have been recorded, synced, or shared with Trailmark. Health does not reveal whether read access was declined.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep window · local time")
                    .font(.caption.weight(.semibold))
                Text("\(dateAndTime(viewModel.windows.sleepStart)) → \(dateAndTime(viewModel.windows.sleepEnd))")
                    .font(.footnote)
                Text("\(TimeZone.current.identifier). From 6 p.m. yesterday until noon today, or the latest refresh time if earlier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Counts time marked asleep, including Core, Deep, REM, and unspecified sleep. Awake and in-bed-only samples are excluded. Overlapping sleep intervals count once and are clipped to this window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .recoveryCard()
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active energy · 7 days", systemImage: "flame.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("\(shortDate(viewModel.windows.energyStart)) – \(shortDate(viewModel.windows.energyEnd)) · kcal")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !viewModel.hasLoaded || viewModel.isLoading {
                loadingPlaceholder("Loading active energy…")
                    .frame(minHeight: 220)
            } else if let message = viewModel.energyErrorMessage {
                errorNotice(message)
            } else {
                if availableEnergyDays.isEmpty {
                    Text("No active-energy samples available")
                        .font(.subheadline.weight(.semibold))
                    Text("Data may be missing, still syncing, or not shared with Trailmark.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(energyTotal.formatted(.number.precision(.fractionLength(0)))) kcal recorded")
                        .font(.title3.weight(.semibold))
                    Text("Samples available on \(availableEnergyDays.count) of 7 days.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                energyChart

                Text("Today is partial, through \(viewModel.windows.energyEnd.formatted(date: .omitted, time: .shortened)). Gaps mean no samples available; a dot at zero means a recorded zero. Resting energy is excluded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DisclosureGroup("Daily values") {
                    VStack(spacing: 12) {
                        ForEach(viewModel.dailyEnergy) { day in
                            dailyEnergyRow(day)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .recoveryCard()
    }

    private var energyChart: some View {
        Chart {
            ForEach(availableEnergyDays) { day in
                if day.kilocalories == 0 {
                    PointMark(
                        x: .value("Date", chartDateLabel(day.date)),
                        y: .value("Active energy (kcal)", 0)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(35)
                } else {
                    BarMark(
                        x: .value("Date", chartDateLabel(day.date)),
                        y: .value("Active energy (kcal)", day.kilocalories)
                    )
                    .foregroundStyle(.orange.gradient)
                    .cornerRadius(4)
                }
            }
        }
        .chartXScale(domain: viewModel.dailyEnergy.map { chartDateLabel($0.date) })
        .chartYScale(domain: 0...chartMaximum)
        .chartYAxisLabel("kcal")
        .chartXAxis {
            AxisMarks(values: viewModel.dailyEnergy.map { chartDateLabel($0.date) }) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let label = value.as(String.self),
                       let date = viewModel.dailyEnergy.first(where: { chartDateLabel($0.date) == label })?.date {
                        VStack(spacing: 2) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                            Text(label)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active energy for the last seven calendar days")
        .accessibilityValue(energyAccessibilitySummary)
        .accessibilityHint("Expand Daily values below for each day's date and energy.")
    }

    private func dailyEnergyRow(_ day: DailyEnergy) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(dailyDateLabel(day))
                Spacer()
                Text(energyValue(day))
                    .foregroundStyle(day.hasSamples ? .primary : .secondary)
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(dailyDateLabel(day))
                Text(energyValue(day))
                    .foregroundStyle(day.hasSamples ? .primary : .secondary)
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.date.formatted(date: .complete, time: .omitted))\(isToday(day.date) ? ", today so far" : "")")
        .accessibilityValue(energyValue(day))
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sample workout", systemImage: "figure.walk")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("20-minute indoor walk")
                .font(.title3.weight(.semibold))
            Text("120 kcal active energy · 1.5 km · 128 BPM average")
                .font(.subheadline)
            Text("This is synthetic assignment data. Tapping Save writes a completed sample workout with energy, distance, and average heart rate to Apple Health; these values can affect your Health totals.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.saveSampleWorkout() }
            } label: {
                if viewModel.isSavingWorkout {
                    HStack {
                        ProgressView()
                        Text("Saving to Health…")
                    }
                } else if viewModel.savedWorkout != nil {
                    Label("Sample workout saved", systemImage: "checkmark.circle")
                } else {
                    Label("Save sample to Apple Health", systemImage: "heart.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSavingWorkout || viewModel.savedWorkout != nil)

            if let message = viewModel.workoutErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Workout save error: \(message)")
            }

            if let message = viewModel.workoutStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let receipt = viewModel.savedWorkout {
                Divider()
                Text("Saved workout details")
                    .font(.subheadline.weight(.semibold))
                Text("\(dateAndTime(receipt.startDate)) → \(dateAndTime(receipt.endDate))")
                    .font(.footnote)
                Text("\(durationText(receipt.duration)) · \(receipt.energyKilocalories.formatted(.number.precision(.fractionLength(0)))) kcal · \((receipt.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(1)))) km · \(receipt.averageHeartRateBPM.formatted(.number.precision(.fractionLength(0)))) BPM")
                    .font(.footnote)
            }

            Divider()
            Text("Verify in the Health app")
                .font(.subheadline.weight(.semibold))
            Text("Open Health → Search (or Browse) → Activity → Workouts → Show All Data. Open the walking workout matching the saved date and time, and check its duration and source. Record that screen for your assignment submission.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("A successful save confirms HealthKit accepted the workout. You still need to visually verify it in Health.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .recoveryCard()
    }

    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
            Button("Retry Health data") {
                Task { await viewModel.refresh() }
            }
            .font(.footnote.weight(.semibold))
            .disabled(viewModel.isLoading)
        }
    }

    private func loadingPlaceholder(_ label: String) -> some View {
        ProgressView(label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }

    private var availableEnergyDays: [DailyEnergy] {
        viewModel.dailyEnergy.filter(\.hasSamples)
    }

    private var energyTotal: Double {
        availableEnergyDays.reduce(0) { $0 + $1.kilocalories }
    }

    private var energyAccessibilitySummary: String {
        "\(energyTotal.formatted(.number.precision(.fractionLength(0)))) kilocalories recorded across \(availableEnergyDays.count) of seven days with available samples. Today is partial. Days without samples are unavailable, not zero."
    }

    private var chartMaximum: Double {
        max(100, (availableEnergyDays.map(\.kilocalories).max() ?? 0) * 1.15)
    }

    private func energyValue(_ day: DailyEnergy) -> String {
        day.hasSamples
            ? "\(day.kilocalories.formatted(.number.precision(.fractionLength(0)))) kcal"
            : "Unavailable"
    }

    private func dailyDateLabel(_ day: DailyEnergy) -> String {
        let date = day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return isToday(day.date) ? "\(date) · Today so far" : date
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: viewModel.windows.energyEnd)
    }

    private func dateAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func chartDateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded()))
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func spokenDuration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded()))
        return "\(minutes / 60) hours and \(minutes % 60) minutes"
    }
}

private extension View {
    func recoveryCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RecoveryView(viewModel: RecoveryViewModel())
}
