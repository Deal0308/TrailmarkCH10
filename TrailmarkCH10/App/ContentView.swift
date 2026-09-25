import SwiftUI
import TrailMarkCH10Core

struct ContentView: View {
    let appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TabView {
            TodayDashboardView(viewModel: appModel.todayViewModel)
                .tabItem { Label("Today", systemImage: "sun.max") }
            Group {
                if let journal = appModel.journalViewModel { FieldJournalView(viewModel: journal) }
                else { storageProblem("Field Journal", message: appModel.journalStorageError) }
            }.tabItem { Label("Journal", systemImage: "book.closed") }
            RecoveryView(viewModel: appModel.recoveryViewModel)
                .tabItem { Label("Recovery", systemImage: "moon.stars") }
            WorkoutView(viewModel: appModel.workoutViewModel)
                .tabItem { Label("Workout", systemImage: "figure.walk") }
            Group {
                if let journeys = appModel.journeysViewModel { JourneysView(viewModel: journeys, journal: appModel.journalViewModel, sync: appModel.pocketSyncViewModel) }
                else { storageProblem("Journeys", message: appModel.journeyStorageError) }
            }.tabItem { Label("Journeys", systemImage: "map") }
        }
        .tint(TrailmarkTheme.accent(for: scheme))
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets cause .inactive; only a real background transition pauses routes.
            if phase == .background { appModel.journeysViewModel?.setForeground(false) }
            if phase == .active {
                appModel.journeysViewModel?.setForeground(true)
                appModel.pocketSyncViewModel.retry()
            }
        }
    }
    private func storageProblem(_ title: String, message: String?) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TrailmarkEmptyState(title: "Let’s try that again", message: message ?? "This feature’s storage couldn’t be opened.", systemImage: "externaldrive.badge.exclamationmark")
                    Button("Retry storage", systemImage: "arrow.clockwise") { appModel.retryStorage() }
                        .buttonStyle(TrailmarkPrimaryButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .trailmarkScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
