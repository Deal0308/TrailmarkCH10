import SwiftUI
import TrailMarkCH10Core

/// The watch composition root reuses the package's view model and Health service.
@main
struct TrailMarkWatchCh10_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WorkoutLaunchDelegate.self) private var applicationDelegate
    @State private var homeViewModel: TodayViewModel
    @State private var liveVitalsViewModel: LiveVitalsViewModel
    @State private var workoutViewModel = WorkoutViewModel()
    @State private var memoViewModel = WatchMemoViewModel()
    @State private var selectedPage: WatchPage = .home

    init() {
        // Wrist Home and Live Vitals share one package-owned HealthKit manager.
        let healthService = ActivityHealthService(scope: .stepsOnly)
        _homeViewModel = State(initialValue: TodayViewModel(service: healthService))
        _liveVitalsViewModel = State(initialValue: LiveVitalsViewModel(service: healthService))
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedPage) {
                WatchHomeView(viewModel: homeViewModel, workoutViewModel: workoutViewModel)
                    .tag(WatchPage.home)
                WatchMemoListView(viewModel: memoViewModel)
                    .tag(WatchPage.memos)
                WatchLiveVitalsView(
                    viewModel: liveVitalsViewModel,
                    isSelected: selectedPage == .liveVitals
                )
                .tag(WatchPage.liveVitals)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

private enum WatchPage: Hashable {
    case home
    case memos
    case liveVitals
}
