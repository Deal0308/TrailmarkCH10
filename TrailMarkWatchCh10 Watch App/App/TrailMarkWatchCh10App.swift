import SwiftUI
import TrailMarkCH10Core

/// The watch composition root reuses the package's view model and Health service.
@main
struct TrailMarkWatchCh10_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WorkoutLaunchDelegate.self) private var applicationDelegate
    @State private var homeViewModel: TodayViewModel
    @State private var liveVitalsViewModel: LiveVitalsViewModel
    @State private var workoutViewModel: WorkoutViewModel
    @State private var memoViewModel: WatchMemoViewModel
    @State private var motionViewModel = MotionViewModel()
    @State private var selectedPage: WatchPage = .home
    private let pocketSyncService: PocketSyncService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Wrist Home and Live Vitals share one package-owned HealthKit manager.
        let healthService = ActivityHealthService(scope: .stepsOnly, requestsAuthorizationOnRead: false)
        let pocketSync = PocketSyncService()
        let workout = WorkoutViewModel(pocketSync: pocketSync)
        pocketSyncService = pocketSync
        _workoutViewModel = State(initialValue: workout)
        _memoViewModel = State(initialValue: WatchMemoViewModel(pocketSync: pocketSync))
        _homeViewModel = State(initialValue: TodayViewModel(service: healthService))
        _liveVitalsViewModel = State(initialValue: LiveVitalsViewModel(service: healthService, workoutViewModel: workout))
        pocketSync.activate()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedPage) {
                WatchHomeView(
                    viewModel: homeViewModel,
                    workoutViewModel: workoutViewModel,
                    isHealthEnabled: liveVitalsViewModel.isHealthEnabled,
                    isSelected: selectedPage == .home
                )
                    .tag(WatchPage.home)
                WatchMemoListView(viewModel: memoViewModel, isSelected: selectedPage == .memos)
                    .tag(WatchPage.memos)
                WatchLiveVitalsView(
                    viewModel: liveVitalsViewModel,
                    isSelected: selectedPage == .liveVitals
                )
                .tag(WatchPage.liveVitals)
                WatchMotionView(viewModel: motionViewModel, isSelected: selectedPage == .motion)
                    .tag(WatchPage.motion)
            }
            .tabViewStyle(.verticalPage)
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { pocketSyncService.retry() }
            }
        }
    }
}

private enum WatchPage: Hashable {
    case home
    case memos
    case liveVitals
    case motion
}
