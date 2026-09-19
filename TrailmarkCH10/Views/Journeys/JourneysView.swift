import SwiftUI
import TrailMarkCH10Core

struct JourneysView: View {
    let viewModel: JourneysViewModel
    let journal: JournalViewModel?
    @State private var showingStart = false
    @State private var title = ""
    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
                if let active = viewModel.activeJourney {
                    Section("Active journey") {
                        journeyLink(active)
                        Text(viewModel.location.message).font(.footnote).foregroundStyle(.secondary)
                        Text("Keep Trailmark in the foreground to collect route points. You can use the other tabs while recording.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                let saved = viewModel.journeys.filter { $0.id != viewModel.activeJourney?.id }
                if saved.isEmpty && viewModel.activeJourney == nil {
                    ContentUnavailableView("No Journeys", systemImage: "map", description: Text("Start a journey to bring your route, field memos, and Health data together."))
                } else if !saved.isEmpty {
                    Section("Saved journeys") { ForEach(saved) { journey in journeyLink(journey) } }
                }
            }
            .navigationTitle("Journeys")
            .toolbar {
                Button("Start journey", systemImage: "plus") { title = ""; showingStart = true }
                    .disabled(viewModel.activeJourney != nil)
            }
            .sheet(isPresented: $showingStart) {
                NavigationStack {
                    Form {
                        Section("Journey name") { TextField("Afternoon walk", text: $title) }
                        Section {
                            Text("Trailmark requests location while you use the app. Route points and memo locations are stored on this iPhone.")
                            Text("Location is optional: denied access leaves the route empty, but you can still save the journey and its memos.")
                        }.font(.footnote)
                        Button("Start recording journey", systemImage: "location.fill") {
                            viewModel.start(title: title)
                            showingStart = false
                        }
                    }
                    .navigationTitle("New Journey")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingStart = false } } }
                }
            }
        }
    }
    private func journeyLink(_ journey: Journey) -> some View {
        NavigationLink {
            JourneyDetailView(viewModel: JourneyDetailViewModel(journeyID: journey.id, journeys: viewModel, journal: journal))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(journey.title).font(.headline)
                Text(journey.startDate, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                Text("\(journey.distanceText) · \(journey.durationText) · \(journey.status.rawValue.capitalized)").font(.subheadline)
            }.padding(.vertical, 4)
        }
    }
}
