import Foundation
import Observation

/// Recovery state is independent of the Today dashboard and the journal.
@MainActor
@Observable
public final class RecoveryViewModel {
    public private(set) var windows: RecoveryDateWindows
    public private(set) var sleepDuration: TimeInterval?
    public private(set) var dailyEnergy: [DailyEnergy] = []
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    public private(set) var sleepErrorMessage: String?
    public private(set) var energyErrorMessage: String?
    public private(set) var authorizationErrorMessage: String?
    public private(set) var isSavingWorkout = false
    public private(set) var workoutStatusMessage: String?
    public private(set) var workoutErrorMessage: String?
    public private(set) var savedWorkout: SampleWorkoutReceipt?

    @ObservationIgnored private let provider: any RecoveryHealthProviding
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private var sampleActivity: SampleWorkoutActivity?
    @ObservationIgnored private var refreshRequested = false

    public init(
        provider: (any RecoveryHealthProviding)? = nil,
        now: @escaping () -> Date = { Date() },
        calendar: @escaping () -> Calendar = { Calendar.current }
    ) {
        self.provider = provider ?? HealthKitRecoveryStore()
        self.now = now
        self.calendar = calendar
        self.windows = RecoveryDateWindowProvider.windows(now: now(), calendar: calendar())
    }

    public func load() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    public func refresh() async {
        guard !isLoading else {
            // A completed save can request newer data while an earlier read is still pending.
            // Coalesce those requests into another pass instead of dropping the update.
            refreshRequested = true
            return
        }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        repeat {
            refreshRequested = false
            await performRefresh()
        } while refreshRequested
    }

    private func performRefresh() async {
        authorizationErrorMessage = nil
        sleepErrorMessage = nil
        energyErrorMessage = nil
        let timestamp = now()
        let queryCalendar = calendar()
        windows = RecoveryDateWindowProvider.windows(now: timestamp, calendar: queryCalendar)
        sleepDuration = nil
        dailyEnergy = RecoveryDateWindowProvider.energyDays(now: timestamp, calendar: queryCalendar)
            .map { DailyEnergy(date: $0, kilocalories: 0, hasSamples: false) }

        do {
            try await provider.requestReadAuthorization()
        } catch {
            authorizationErrorMessage = error.localizedDescription
            return
        }

        // Each query handles its own failure, allowing the other result to remain useful.
        async let sleep: Void = loadSleep(window: DateInterval(start: windows.sleepStart, end: windows.sleepEnd))
        async let energy: Void = loadEnergy(windows: windows, calendar: queryCalendar)
        _ = await (sleep, energy)
    }

    private func loadSleep(window: DateInterval) async {
        do {
            sleepDuration = try await provider.readSleep(in: window)
        } catch {
            sleepErrorMessage = "Sleep could not be loaded. \(error.localizedDescription)"
        }
    }

    private func loadEnergy(windows: RecoveryDateWindows, calendar: Calendar) async {
        do {
            dailyEnergy = try await provider.readEnergy(windows: windows, calendar: calendar)
        } catch {
            energyErrorMessage = "Active energy could not be loaded. \(error.localizedDescription)"
        }
    }

    public func saveSampleWorkout() async {
        guard !isSavingWorkout, savedWorkout == nil else { return }
        isSavingWorkout = true
        workoutErrorMessage = nil
        workoutStatusMessage = nil
        defer { isSavingWorkout = false }

        // Retain the identity and dates on retry to avoid duplicating sample quantities.
        let activity = sampleActivity ?? SampleWorkoutActivity(endingAt: now())
        sampleActivity = activity
        do {
            savedWorkout = try await provider.saveSampleWorkout(activity)
            workoutStatusMessage = "HealthKit confirmed the save. Open Health to verify and record this workout for your submission."
            await refresh()
        } catch {
            workoutErrorMessage = error.localizedDescription
        }
    }
}

/// Source compatibility for earlier assignment code.
public typealias RecoveryHealthManager = RecoveryViewModel
