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
    private(set) var journalViewModel: JournalViewModel?
    private(set) var journeysViewModel: JourneysViewModel?
    private(set) var journalStorageError: String?
    private(set) var journeyStorageError: String?

    init() { prepareStorage() }
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
    }
}
