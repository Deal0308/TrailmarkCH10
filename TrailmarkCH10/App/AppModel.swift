import Foundation
import Observation
import TrailMarkCH10Core

/// Composition root: constructs shared dependencies without implementing platform logic.
@MainActor
@Observable
final class AppModel {
    let todayViewModel = TodayViewModel()
    let recoveryViewModel = RecoveryViewModel()
    let workoutViewModel = WorkoutViewModel()
    let pocketSyncService = PocketSyncService()
    private(set) var journalViewModel: JournalViewModel?
    private(set) var journeysViewModel: JourneysViewModel?
    private(set) var journalStorageError: String?
    private(set) var journeyStorageError: String?
    @ObservationIgnored private var pendingPocketMemos: [IncomingPocketMemo] = []

    init() {
        prepareStorage()
        configurePocketSync()
        pocketSyncService.activate()
    }
    func prepareStorage() {
        if journeysViewModel == nil {
            do {
                journeysViewModel = JourneysViewModel(store: try JourneyStore())
                journeyStorageError = nil
            } catch { journeyStorageError = "Journeys could not open local storage. Existing files were preserved. \(error.localizedDescription)" }
        }
        if journalViewModel == nil {
            do {
                journalViewModel = JournalViewModel(store: try JournalMediaStore(), journeys: journeysViewModel)
                journalStorageError = nil
            } catch { journalStorageError = "The journal could not open local storage. Existing files were preserved. \(error.localizedDescription)" }
        }
        journalViewModel?.connect(journeys: journeysViewModel)
        importPendingPocketMemos()
    }

    private func configurePocketSync() {
        pocketSyncService.configureReceiving(
            activity: { [weak self] record in
                self?.journeysViewModel?.importWatchActivity(record)
            },
            memo: { [weak self] memo in
                guard let self else { return }
                if let journalViewModel {
                    Task { await journalViewModel.importPocketMemo(memo) }
                } else {
                    pendingPocketMemos.append(memo)
                }
            },
            summary: { [weak self] summary in
                self?.journeysViewModel?.receivePocketSyncSummary(summary)
            }
        )
    }

    private func importPendingPocketMemos() {
        guard let journalViewModel, !pendingPocketMemos.isEmpty else { return }
        let pending = pendingPocketMemos
        pendingPocketMemos.removeAll()
        Task {
            for memo in pending { await journalViewModel.importPocketMemo(memo) }
        }
    }
}
