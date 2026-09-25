import SwiftUI
import TrailMarkCH10Core

struct JourneyDetailView: View {
    @State var viewModel: JourneyDetailViewModel
    @State private var showingRecorder = false
    @State private var selectedMemo: JournalMedia?
    @State private var confirmingFinish = false
    @State private var showingHelp = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let journey = viewModel.journey {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        journeyHeader(journey)
                        if let feedback = viewModel.feedback, !viewModel.isActive {
                            TrailmarkFeedback(feedback) { viewModel.dismissFeedback() }
                        }
                        if let feedback = viewModel.journal?.feedback {
                            TrailmarkFeedback(feedback) { viewModel.journal?.dismissFeedback() }
                        }
                        routeCard(journey)
                        if journey.watchActivity == nil {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(spacing: 12) { routeMetrics(journey) }
                            } else {
                                HStack(alignment: .top, spacing: 12) { routeMetrics(journey) }
                            }
                        }

                        if let watchActivity = journey.watchActivity {
                            watchActivityCard(watchActivity)
                        }

                        if viewModel.isActive {
                            VStack(spacing: 12) {
                                Button("Add a field memo", systemImage: "mic.fill") { showingRecorder = true }
                                    .buttonStyle(TrailmarkPrimaryButtonStyle())
                                    .disabled(viewModel.journal == nil)
                                Button("Finish journey", systemImage: "stop.circle", role: .destructive) { confirmingFinish = true }
                                    .buttonStyle(TrailmarkSecondaryButtonStyle())
                            }
                            TrailmarkNotice(title: "Along the way", message: viewModel.routeMessage, systemImage: "location")
                            Button("Route & location help", systemImage: "questionmark.circle") { showingHelp = true }
                                .buttonStyle(TrailmarkSecondaryButtonStyle())
                        }
                        if let error = viewModel.routeError {
                            TrailmarkNotice(title: "Route update", message: error,
                                            systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                        }
                        healthCard(journey)
                        memoSection
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            } else {
                ScrollView {
                    TrailmarkEmptyState(title: "Journey unavailable.",
                                        message: "This journey could not be found in local storage.", systemImage: "map")
                        .padding(20)
                }
            }
        }
        .trailmarkScreen()
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingHelp) { TrailmarkHelpView() }
        .sensoryFeedback(.success, trigger: viewModel.journal?.feedback?.id) { _, next in next != nil }
        .sensoryFeedback(.success, trigger: viewModel.feedback?.id) { _, next in next != nil }
        .task { await viewModel.refreshHealth() }
        .refreshable { await viewModel.refreshHealth() }
        .sheet(isPresented: $showingRecorder) {
            if let journal = viewModel.journal { JournalCaptureView(viewModel: journal.makeCaptureViewModel()) }
        }
        .sheet(item: $selectedMemo) { memo in
            if let journal = viewModel.journal {
                NavigationStack {
                    JournalMediaDetailView(viewModel: journal.makeDetailViewModel(item: memo))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selectedMemo = nil }.frame(minHeight: 44)
                            }
                        }
                }
            }
        }
        .confirmationDialog("Finish recording this journey?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish journey") { Task { await viewModel.finish() } }
        }
    }

    private func journeyHeader(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TrailmarkBadge(
                journey.watchActivity != nil ? "SYNCED FROM WATCH" : journey.status == .recording ? "IN PROGRESS" : journey.status == .interrupted ? "INTERRUPTED" : "IN YOUR COLLECTION",
                systemImage: journey.watchActivity != nil ? "applewatch" : journey.status == .recording ? "location.fill" : "flag.checkered",
                tint: journey.status == .interrupted ? TrailmarkTheme.clay : nil
            )
            TrailmarkSectionHeader(eyebrow: "THE JOURNEY", title: journey.title,
                                   subtitle: journey.startDate.formatted(date: .long, time: .shortened))
            if let end = journey.endDate {
                Text("Ended \(end.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if journey.status == .interrupted {
                TrailmarkNotice(title: "Saved up to your last checkpoint",
                                message: "The app closed during recording. This route ends at the last saved GPS checkpoint.",
                                systemImage: "pause.circle", tint: TrailmarkTheme.clay)
            }
        }
    }

    private func routeCard(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(journey.watchActivity == nil ? "Your route" : "Watch capture")
                    .font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "map").foregroundStyle(TrailmarkTheme.accent(for: colorScheme)).accessibilityHidden(true)
            }
            if journey.points.isEmpty && viewModel.memos.allSatisfy({ $0.coordinate == nil }) {
                TrailmarkEmptyState(
                    title: journey.watchActivity == nil ? "Room for a route." : "Activity recorded on your wrist.",
                    message: journey.watchActivity == nil
                        ? (viewModel.isActive ? "Waiting for accurate location updates. Health and memos are available here even without a route." : "No route was recorded for this journey. Your saved activity and memos remain available below.")
                        : "Pocket Sync transfers the completed activity record and attached memos. This watch workout did not include route points.",
                    systemImage: journey.watchActivity == nil ? "location.slash" : "applewatch"
                )
            } else {
                JourneyMapSurface(journey: journey, memos: viewModel.memos) { selectedMemo = $0 }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            DisclosureGroup("About this route") {
                Text("GPS route distance · elapsed journey time. Gaps in location coverage are not connected by a line.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
            }
            .font(.subheadline)
        }
        .trailmarkCard(padding: 16)
    }

    private func watchActivityCard(_ activity: WatchActivityRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Watch activity", systemImage: "applewatch")
                .font(.title3.weight(.semibold))
            Text("Recorded on Apple Watch and delivered with Pocket Sync.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack { Label("Active duration", systemImage: "clock"); Spacer(); Text(activity.durationText).fontWeight(.semibold).monospacedDigit() }
                    VStack(alignment: .leading, spacing: 6) { Label("Active duration", systemImage: "clock"); Text(activity.durationText).fontWeight(.semibold).monospacedDigit() }
                }
                Divider()
                metric("Average heart rate", value: activity.averageHeartRateBPM, unit: "BPM", systemImage: "heart.fill")
                Divider()
                metric("Workout energy", value: activity.activeEnergyKilocalories, unit: "kcal", systemImage: "flame.fill")
            }
            .font(.subheadline)
        }
        .trailmarkCard()
    }

    @ViewBuilder
    private func routeMetrics(_ journey: Journey) -> some View {
        TrailmarkMetricTile(title: "GPS distance", value: journey.distanceText,
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath", tint: TrailmarkTheme.sky)
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "clock")
                .font(.body.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? TrailmarkTheme.cream : TrailmarkTheme.gold)
                .frame(width: 38, height: 38)
                .background(TrailmarkTheme.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Elapsed time").font(.subheadline).foregroundStyle(.secondary)
                Group {
                    if viewModel.isActive { Text(journey.startDate, style: .timer) }
                    else { Text(journey.durationText) }
                }
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailmarkCard()
        .accessibilityElement(children: .combine)
    }

    private func healthCard(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill").foregroundStyle(TrailmarkTheme.clay).accessibilityHidden(true)
                Text("Health along the way").font(.title3.weight(.semibold))
            }
            Text("Readings within this journey")
                .font(.caption).foregroundStyle(.secondary)
            if viewModel.isLoadingHealth { ProgressView("Refreshing Health…") }
            if let error = viewModel.healthError {
                TrailmarkNotice(title: "Health update", message: error,
                                systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
            }
            VStack(spacing: 16) {
                metric("Steps", value: journey.health?.steps, unit: "steps", systemImage: "shoeprints.fill")
                Divider()
                metric("Health distance", value: journey.health?.distanceMeters.map { $0 / 1000 }, unit: "km",
                       systemImage: "figure.walk", decimals: 2)
                Divider()
                metric("Active energy", value: journey.health?.activeEnergyKilocalories, unit: "kcal", systemImage: "flame")
                Divider()
                metric("Hydration", value: journey.health?.hydrationMilliliters, unit: "mL", systemImage: "drop")
            }
            if let date = journey.health?.queriedAt {
                Text("Last read \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh journey Health", systemImage: "arrow.clockwise") { Task { await viewModel.refreshHealth() } }
                .buttonStyle(TrailmarkSecondaryButtonStyle())
                .disabled(viewModel.isLoadingHealth)
            DisclosureGroup("How these readings are collected") {
                Text("Includes readable Health samples fully within the journey's start and end (now while recording). Boundary-spanning samples may be omitted. Health distance can differ from GPS distance. Unavailable does not establish whether read access was declined.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
            }
            .font(.subheadline)
        }
        .trailmarkCard()
    }

    private func metric(_ title: String, value: Double?, unit: String, systemImage: String, decimals: Int = 0) -> some View {
        let formatted = value.map { "\($0.formatted(.number.precision(.fractionLength(decimals)))) \(unit)" } ?? "Unavailable"
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: 8)
                Text(formatted).fontWeight(.semibold).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                Text(formatted).fontWeight(.semibold).monospacedDigit()
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Field memories", systemImage: "book.closed").font(.title3.weight(.semibold))
                Spacer()
                Text("\(viewModel.memos.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let journal = viewModel.journal {
                if viewModel.memos.isEmpty {
                    Text(viewModel.isActive ? "Add a voice or video memo here, or in Field Journal while this journey is active." : "No memos were attached to this journey.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(viewModel.memos) { memo in
                    Button { selectedMemo = memo } label: {
                        HStack(spacing: 8) {
                            JournalMediaRow(item: memo, viewModel: journal)
                            Image(systemName: "play.circle").font(.title3).accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    if memo.id != viewModel.memos.last?.id { Divider() }
                }
                if viewModel.memosWithoutPins > 0 {
                    DisclosureGroup("Memos without map pins") {
                        Text("\(viewModel.memosWithoutPins) memo(s) have no capture location. They remain associated here, but do not appear as map pins.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                    }
                    .font(.subheadline)
                }
                if let error = journal.errorMessage {
                    TrailmarkNotice(title: "Journal update", message: error,
                                    systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                }
            } else {
                Text("Journal storage is unavailable. Open Field Journal to retry.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .trailmarkCard()
    }
}
