import SwiftUI
import TrailMarkCH10Core

struct JourneyDetailView: View {
    @State var viewModel: JourneyDetailViewModel
    @State private var showingRecorder = false
    @State private var selectedMemo: JournalMedia?
    @State private var confirmingFinish = false

    var body: some View {
        Group {
            if let journey = viewModel.journey {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(journey.status == .recording ? "JOURNEY IN PROGRESS" : journey.status == .interrupted ? "INTERRUPTED JOURNEY" : "COMPLETED JOURNEY")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(journey.title).font(.title2.bold())
                            Text(journey.startDate, format: .dateTime.month(.wide).day().year().hour().minute()).font(.subheadline)
                            if let end = journey.endDate { Text("Ended \(end.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                            if journey.status == .interrupted { Text("The app closed during recording. This route ends at the last saved GPS checkpoint.").font(.footnote).foregroundStyle(.secondary) }
                        }

                        JourneyMapSurface(journey: journey, memos: viewModel.memos) { selectedMemo = $0 }
                            .frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 16))
                        HStack {
                            Label(journey.distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            Spacer()
                            if viewModel.isActive { Text(journey.startDate, style: .timer).monospacedDigit() }
                            else { Label(journey.durationText, systemImage: "clock") }
                        }.font(.headline)
                        Text("GPS route distance · elapsed journey time. Gaps in location coverage are not connected by a line.").font(.caption).foregroundStyle(.secondary)
                        if viewModel.isActive {
                            Text(viewModel.routeMessage).font(.footnote).foregroundStyle(.secondary)
                            HStack {
                                Button("Add memo", systemImage: "mic.fill") { showingRecorder = true }.disabled(viewModel.journal == nil)
                                Spacer()
                                Button("Finish journey", systemImage: "stop.circle") { confirmingFinish = true }.tint(.red)
                            }.buttonStyle(.bordered)
                        }
                        if let error = viewModel.routeError { Text(error).font(.footnote).foregroundStyle(.red) }

                        healthCard(journey)
                        memoSection
                    }.padding()
                }
                .background(Color(.systemGroupedBackground))
            } else { ContentUnavailableView("Journey unavailable", systemImage: "map", description: Text("This journey could not be found in local storage.")) }
        }
        .navigationTitle("Journey Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refreshHealth() }
        .refreshable { await viewModel.refreshHealth() }
        .sheet(isPresented: $showingRecorder) {
            if let journal = viewModel.journal { JournalCaptureView(viewModel: journal.makeCaptureViewModel()) }
        }
        .sheet(item: $selectedMemo) { memo in
            if let journal = viewModel.journal {
                NavigationStack {
                    JournalMediaDetailView(viewModel: journal.makeDetailViewModel(item: memo))
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { selectedMemo = nil } } }
                }
            }
        }
        .confirmationDialog("Finish recording this journey?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish journey") { Task { await viewModel.finish() } }
        }
    }

    private func healthCard(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Health during this journey", systemImage: "heart.fill").font(.headline)
            if viewModel.isLoadingHealth { ProgressView("Refreshing Health…") }
            if let error = viewModel.healthError { Text(error).font(.footnote).foregroundStyle(.red) }
            metric("Steps", value: journey.health?.steps, unit: "steps")
            metric("Health distance", value: journey.health?.distanceMeters.map { $0 / 1000 }, unit: "km", decimals: 2)
            metric("Active energy", value: journey.health?.activeEnergyKilocalories, unit: "kcal")
            metric("Hydration", value: journey.health?.hydrationMilliliters, unit: "mL")
            if let date = journey.health?.queriedAt { Text("Last read \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            Text("Includes readable Health samples fully within the journey's start and end (now while recording). Boundary-spanning samples may be omitted. Health distance can differ from GPS distance. Unavailable does not establish whether read access was declined.").font(.caption).foregroundStyle(.secondary)
            Button("Refresh journey Health", systemImage: "arrow.clockwise") { Task { await viewModel.refreshHealth() } }.disabled(viewModel.isLoadingHealth)
        }
        .padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, value: Double?, unit: String, decimals: Int = 0) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map { "\($0.formatted(.number.precision(.fractionLength(decimals)))) \(unit)" } ?? "Unavailable")
                .monospacedDigit().foregroundStyle(value == nil ? .secondary : .primary)
        }.font(.subheadline)
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Journey memos · \(viewModel.memos.count)", systemImage: "book.closed").font(.headline)
            if let journal = viewModel.journal {
                if viewModel.memos.isEmpty {
                    Text(viewModel.isActive ? "Add a voice or video memo here, or in Field Journal while this journey is active." : "No memos were attached to this journey.").foregroundStyle(.secondary)
                }
                ForEach(viewModel.memos) { memo in
                    Button { selectedMemo = memo } label: { JournalMediaRow(item: memo, viewModel: journal) }.buttonStyle(.plain)
                    Divider()
                }
                if viewModel.memosWithoutPins > 0 { Text("\(viewModel.memosWithoutPins) memo(s) have no capture location. They remain associated here, but do not appear as map pins.").font(.caption).foregroundStyle(.secondary) }
                if let error = journal.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
            } else { Text("Journal storage is unavailable. Open Field Journal to retry.").foregroundStyle(.secondary) }
        }
        .padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
