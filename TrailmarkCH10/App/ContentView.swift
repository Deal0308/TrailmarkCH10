import SwiftUI
import TrailMarkCH10Core

struct ContentView: View {
    let appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            TodayDashboardView(viewModel: appModel.todayViewModel)
                .tabItem { Label("Today", systemImage: "calendar") }
            Group {
                if let journal = appModel.journalViewModel { FieldJournalView(viewModel: journal) }
                else { storageProblem("Field Journal", message: appModel.journalStorageError) }
            }.tabItem { Label("Field Journal", systemImage: "book.closed") }
            RecoveryView(viewModel: appModel.recoveryViewModel)
                .tabItem { Label("Recovery", systemImage: "heart.text.square") }
            WorkoutView(viewModel: appModel.workoutViewModel)
                .tabItem { Label("Workout", systemImage: "figure.run") }
            Group {
                if let journeys = appModel.journeysViewModel { JourneysView(viewModel: journeys, journal: appModel.journalViewModel) }
                else { storageProblem("Journeys", message: appModel.journeyStorageError) }
            }.tabItem { Label("Journeys", systemImage: "map") }
        }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets cause .inactive; only a real background transition pauses routes.
            if phase == .background { appModel.journeysViewModel?.setForeground(false) }
            if phase == .active { appModel.journeysViewModel?.setForeground(true) }
        }
    }
    private func storageProblem(_ title: String, message: String?) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(message ?? "This feature's storage could not be opened.")
            } actions: { Button("Retry") { appModel.prepareStorage() } }
            .navigationTitle(title)
        }
    }
}
