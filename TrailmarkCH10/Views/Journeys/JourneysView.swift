import SwiftUI
import TrailMarkCH10Core

struct JourneysView: View {
    let viewModel: JourneysViewModel
    let journal: JournalViewModel?
    @State private var showingStart = false
    @State private var title = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(
                        eyebrow: "GO SOMEWHERE GOOD",
                        title: "Your journeys.",
                        subtitle: "Routes, memories, and movement. Together."
                    )
                    if let error = viewModel.errorMessage {
                        TrailmarkNotice(title: "A journey update", message: error,
                                        systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                    }
                    if let summary = viewModel.latestPocketSyncSummary {
                        TrailmarkNotice(
                            title: "Pocket Sync",
                            message: "Latest watch activity: \(summary.activityDate.formatted(date: .abbreviated, time: .shortened)) · \(durationText(summary.duration)). Background delivery does not require both apps to stay open.",
                            systemImage: "applewatch"
                        )
                    }

                    if let active = viewModel.activeJourney {
                        activeJourneyCard(active)
                        VStack(alignment: .leading, spacing: 10) {
                            Label(viewModel.location.message, systemImage: "location")
                                .font(.footnote).foregroundStyle(.secondary)
                            DisclosureGroup("Recording your route") {
                                Text("Keep Trailmark in the foreground to collect route points. You can use the other tabs while recording.")
                                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                            }
                            .font(.subheadline.weight(.medium))
                        }
                        .trailmarkCard()
                    } else {
                        startCard
                    }

                    let saved = viewModel.journeys.filter { $0.id != viewModel.activeJourney?.id }
                    if saved.isEmpty {
                        if viewModel.activeJourney == nil {
                            TrailmarkEmptyState(
                                title: "The next chapter is outside.",
                                message: "Start a journey and your route, field memos, and Health summary will come together here.",
                                systemImage: "map"
                            )
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text("The places you've been").font(.title2.weight(.semibold))
                            Spacer()
                            Text("\(saved.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ForEach(saved) { journey in journeyLink(journey) }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .trailmarkScreen()
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { beginNamingJourney() } label: {
                    Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Start journey")
                .disabled(viewModel.activeJourney != nil)
            }
            .sheet(isPresented: $showingStart) { newJourneySheet }
        }
    }

    private var startCard: some View {
        TrailmarkHero {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "location.north.line")
                    .font(.title).foregroundStyle(TrailmarkTheme.lime).accessibilityHidden(true)
                Text("Follow your\ncuriosity.")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Make a place for the path you take and the things you notice along the way.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Button("Start a journey", systemImage: "arrow.up.right") { beginNamingJourney() }
                    .buttonStyle(TrailmarkPrimaryButtonStyle(tint: TrailmarkTheme.lime, foreground: TrailmarkTheme.forest))
            }
        }
    }

    private func activeJourneyCard(_ journey: Journey) -> some View {
        TrailmarkHero {
            VStack(alignment: .leading, spacing: 20) {
                Label("OUT THERE NOW", systemImage: "location.fill")
                    .font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(TrailmarkTheme.lime)
                Text(journey.title)
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { activeStats(journey) }
                    VStack(alignment: .leading, spacing: 16) { activeStats(journey) }
                }
                NavigationLink {
                    JourneyDetailView(viewModel: JourneyDetailViewModel(journeyID: journey.id, journeys: viewModel, journal: journal))
                } label: {
                    Label("Continue journey", systemImage: "arrow.up.right")
                }
                .buttonStyle(TrailmarkPrimaryButtonStyle(tint: TrailmarkTheme.lime, foreground: TrailmarkTheme.forest))
            }
        }
    }

    @ViewBuilder
    private func activeStats(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(journey.distanceText).font(.title2.weight(.semibold)).monospacedDigit()
            Text("GPS distance").font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        VStack(alignment: .leading, spacing: 4) {
            Text(journey.startDate, style: .timer).font(.title2.weight(.semibold)).monospacedDigit()
            Text("Elapsed time").font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func journeyLink(_ journey: Journey) -> some View {
        NavigationLink {
            JourneyDetailView(viewModel: JourneyDetailViewModel(journeyID: journey.id, journeys: viewModel, journal: journal))
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: journey.watchActivity == nil ? "map" : "applewatch")
                        .font(.title3)
                        .foregroundStyle(TrailmarkTheme.accent(for: colorScheme))
                        .frame(width: 48, height: 48)
                        .background(TrailmarkTheme.accent(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(journey.title).font(.headline).foregroundStyle(TrailmarkTheme.ink(for: colorScheme))
                        Text(journey.startDate, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption).foregroundStyle(.secondary)
                        if journey.watchActivity != nil {
                            TrailmarkBadge("SYNCED FROM WATCH", systemImage: "iphone.and.arrow.forward")
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { savedStats(journey) }
                    VStack(alignment: .leading, spacing: 10) { savedStats(journey) }
                }
            }
            .trailmarkCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func savedStats(_ journey: Journey) -> some View {
        if let activity = journey.watchActivity {
            Label("Watch activity", systemImage: "applewatch")
                .font(.subheadline)
            Label(activity.durationText, systemImage: "clock")
                .font(.subheadline.monospacedDigit())
        } else {
            Label(journey.distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.subheadline.monospacedDigit())
            Label(journey.durationText, systemImage: "clock")
                .font(.subheadline.monospacedDigit())
        }
        TrailmarkBadge(journey.status.rawValue.capitalized,
                       tint: journey.status == .interrupted ? TrailmarkTheme.clay : nil)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(max(0, duration).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var newJourneySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(eyebrow: "A FRESH START", title: "Name the day.",
                                           subtitle: "A small beginning. A path of your own.")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("JOURNEY NAME").font(.caption.weight(.semibold)).tracking(1.2)
                        TextField("Afternoon walk", text: $title)
                            .font(.system(.title2, design: .serif))
                            .frame(minHeight: 52)
                            .accessibilityLabel("Journey name")
                    }
                    .trailmarkCard()
                    TrailmarkNotice(title: "Location is your choice",
                                    message: "Your memos and journey can still be saved when location is unavailable.",
                                    systemImage: "location")
                    Button("Start recording journey", systemImage: "location.fill") {
                        viewModel.start(title: title)
                        showingStart = false
                    }
                    .buttonStyle(TrailmarkPrimaryButtonStyle())
                    DisclosureGroup("Location & privacy") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trailmark requests location while you use the app. Route points and memo locations are stored on this iPhone.")
                            Text("Location is optional: denied access leaves the route empty, but you can still save the journey and its memos.")
                        }
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    }
                    .font(.subheadline.weight(.medium))
                    .trailmarkCard()
                }
                .padding(20)
            }
            .trailmarkScreen()
            .navigationTitle("New journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingStart = false }.frame(minHeight: 44)
                }
            }
        }
    }

    private func beginNamingJourney() {
        title = ""
        showingStart = true
    }
}
