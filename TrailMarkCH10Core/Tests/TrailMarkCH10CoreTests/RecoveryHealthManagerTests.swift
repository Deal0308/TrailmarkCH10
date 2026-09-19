import Foundation
import HealthKit
import Testing
@testable import TrailMarkCH10Core

@MainActor
struct RecoveryHealthManagerTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_789_215_600)

    private func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        return calendar
    }

    @Test
    func authorizationIncludesEveryWrittenQuantityAndTheRequiredReads() {
        #expect(Set(HealthKitRecoveryStore.shareTypes.map(\.identifier)) == [
            HKObjectType.workoutType().identifier,
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue
        ])
        #expect(Set(HealthKitRecoveryStore.readTypes.map(\.identifier)) == [
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue,
            HKObjectType.workoutType().identifier
        ])
    }

    @Test
    func sleepParserCountsOnlyAsleepValuesClipsBoundariesAndUnionsStages() {
        let start = referenceDate
        let window = DateInterval(start: start, duration: 360 * 60)
        func sample(_ value: HKCategoryValueSleepAnalysis, _ fromMinute: Double, _ toMinute: Double) -> HKCategorySample {
            HKCategorySample(
                type: HKCategoryType(.sleepAnalysis), value: value.rawValue,
                start: start.addingTimeInterval(fromMinute * 60),
                end: start.addingTimeInterval(toMinute * 60)
            )
        }
        let samples = [
            sample(.inBed, 0, 360), sample(.awake, 120, 180),
            sample(.asleepUnspecified, -10, 60), sample(.asleepCore, 30, 100),
            sample(.asleepDeep, 100, 120), sample(.asleepREM, 180, 210),
            sample(.asleepREM, 180, 210), sample(.asleepCore, 350, 380)
        ]

        // [0,120] + [180,210] + [350,360]. Awake/in-bed data adds no duration.
        #expect(HealthKitRecoveryStore.sleepDuration(samples: samples, window: window) == 160.0 * 60)
    }

    @Test
    func sleepParserHasNoInBedFallbackAndBoundaryOnlySamplesAreEmpty() {
        let start = referenceDate
        let window = DateInterval(start: start, duration: 3_600)
        let nonSleep = [HKCategoryValueSleepAnalysis.inBed, .awake].map { value in
            HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: value.rawValue,
                             start: window.start, end: window.end)
        }
        let outside = [
            HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             start: start.addingTimeInterval(-60), end: start),
            HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                             start: window.end, end: window.end.addingTimeInterval(60))
        ]

        #expect(HealthKitRecoveryStore.sleepDuration(samples: [], window: window) == nil)
        #expect(HealthKitRecoveryStore.sleepDuration(samples: nonSleep, window: window) == nil)
        #expect(HealthKitRecoveryStore.sleepDuration(samples: outside, window: window) == nil)
    }

    @Test
    func energyBucketsPreserveSevenDaysAndDistinguishZeroFromMissing() throws {
        let calendar = try calendar()
        let days = RecoveryDateWindowProvider.energyDays(now: referenceDate, calendar: calendar)
        let energy = HealthKitRecoveryStore.energyBuckets(days: days, quantities: [nil, 0, 123.5])

        #expect(energy.count == 7)
        #expect(energy.map(\.date) == days)
        #expect(energy.map(\.hasSamples) == [false, true, true, false, false, false, false])
        #expect(energy.map(\.kilocalories) == [0, 0, 123.5, 0, 0, 0, 0])
        #expect(HealthKitRecoveryStore.energyBuckets(days: days, quantities: []).allSatisfy { !$0.hasSamples })
    }

    @Test
    func sampleQuantitiesAndReceiptMatchTheAdvertisedActivity() throws {
        let id = try #require(UUID(uuidString: "FCBB1EF0-6343-43D9-8866-EE092337CA25"))
        let activity = SampleWorkoutActivity(id: id, endingAt: referenceDate)
        let samples = HealthKitRecoveryStore.quantitySamples(for: activity)
        let energy = try #require(samples.first { $0.quantityType == HKQuantityType(.activeEnergyBurned) })
        let distance = try #require(samples.first { $0.quantityType == HKQuantityType(.distanceWalkingRunning) })
        let heartRate = try #require(samples.first { $0.quantityType == HKQuantityType(.heartRate) })

        #expect(activity.id == id)
        #expect(activity.duration == 20 * 60)
        #expect(activity.endDate == referenceDate)
        #expect(samples.count == 3)
        #expect(energy.quantity.doubleValue(for: .kilocalorie()) == 120)
        #expect(distance.quantity.doubleValue(for: .meter()) == 1_500)
        #expect(heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) == 128)
        #expect(samples.allSatisfy { $0.startDate == activity.startDate && $0.endDate == activity.endDate })
        #expect(energy.metadata?[HKMetadataKeySyncIdentifier] as? String == "com.trailmark.assignment3.\(id.uuidString).energy")
        #expect(distance.metadata?[HKMetadataKeySyncIdentifier] as? String == "com.trailmark.assignment3.\(id.uuidString).distance")
        #expect(heartRate.metadata?[HKMetadataKeySyncIdentifier] as? String == "com.trailmark.assignment3.\(id.uuidString).heart-rate")
        for sample in samples {
            #expect(sample.metadata?[HKMetadataKeySyncVersion] as? Int == 1)
            #expect(sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
        }
        let workoutMetadata = HealthKitRecoveryStore.metadata(for: id, suffix: "workout")
        #expect(workoutMetadata[HKMetadataKeySyncIdentifier] as? String == "com.trailmark.assignment3.\(id.uuidString).workout")
        #expect(workoutMetadata[HKMetadataKeyIndoorWorkout] as? Bool == true)
        #expect(workoutMetadata[HKMetadataKeyWorkoutBrandName] as? String == "Trailmark Sample Activity")

        let receipt = SampleWorkoutReceipt(id: id, activity: activity)
        #expect(receipt.id == id)
        #expect(receipt.startDate == activity.startDate)
        #expect(receipt.endDate == activity.endDate)
        #expect(receipt.duration == 20 * 60)
        #expect(receipt.energyKilocalories == 120)
        #expect(receipt.distanceMeters == 1_500)
        #expect(receipt.averageHeartRateBPM == 128)
        #expect(SampleWorkoutReceipt(id: nil, activity: activity).id == nil)
    }

    @Test
    func readAuthorizationFailureIsRetryableAndDoesNotRunQueries() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.authorizationError = .authorization
        let calendar = try calendar()
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })

        await manager.load()

        #expect(manager.hasLoaded)
        #expect(!manager.isLoading)
        #expect(manager.authorizationErrorMessage == FakeRecoveryError.authorization.localizedDescription)
        #expect(provider.sleepWindows.isEmpty)
        #expect(provider.energyWindows.isEmpty)
        #expect(manager.sleepDuration == nil)
        #expect(manager.dailyEnergy.count == 7)
        #expect(manager.dailyEnergy.allSatisfy { !$0.hasSamples })

        provider.authorizationError = nil
        provider.sleepResult = 7 * 3_600
        await manager.refresh()

        #expect(provider.authorizationRequests == 2)
        #expect(manager.authorizationErrorMessage == nil)
        #expect(manager.sleepDuration == 7.0 * 3_600)
        #expect(provider.sleepWindows.count == 1)
        #expect(provider.energyWindows.count == 1)
        #expect(!manager.isLoading)
    }

    @Test
    func sleepFailureKeepsEnergyAndARefreshClearsTheError() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.sleepError = .sleep
        let calendar = try calendar()
        let expectedEnergy = [DailyEnergy(date: calendar.startOfDay(for: referenceDate), kilocalories: 321)]
        provider.energyResult = expectedEnergy
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })

        await manager.refresh()

        #expect(manager.sleepDuration == nil)
        #expect(manager.sleepErrorMessage?.contains(FakeRecoveryError.sleep.localizedDescription) == true)
        #expect(manager.dailyEnergy == expectedEnergy)
        #expect(manager.energyErrorMessage == nil)

        provider.sleepError = nil
        provider.sleepResult = 6 * 3_600
        await manager.refresh()

        #expect(manager.sleepErrorMessage == nil)
        #expect(manager.sleepDuration == 6.0 * 3_600)
        #expect(manager.dailyEnergy == expectedEnergy)
    }

    @Test
    func energyFailureKeepsSleepAndARefreshClearsTheError() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.sleepResult = 8 * 3_600
        provider.energyError = .energy
        let calendar = try calendar()
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })

        await manager.refresh()

        #expect(manager.sleepDuration == 8.0 * 3_600)
        #expect(manager.sleepErrorMessage == nil)
        #expect(manager.energyErrorMessage?.contains(FakeRecoveryError.energy.localizedDescription) == true)
        #expect(manager.dailyEnergy.count == 7)
        #expect(manager.dailyEnergy.allSatisfy { !$0.hasSamples })

        provider.energyError = nil
        provider.energyResult = [DailyEnergy(date: calendar.startOfDay(for: referenceDate), kilocalories: 100)]
        await manager.refresh()

        #expect(manager.energyErrorMessage == nil)
        #expect(manager.dailyEnergy.first?.kilocalories == 100)
        #expect(manager.sleepDuration == 8.0 * 3_600)
    }

    @Test
    func emptyReadsRemainUnavailableWithoutClaimingAuthorizationWasDenied() async throws {
        let provider = FakeRecoveryHealthProvider()
        let calendar = try calendar()
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })

        await manager.load()
        await manager.load()

        #expect(provider.authorizationRequests == 1)
        #expect(manager.hasLoaded)
        #expect(manager.sleepDuration == nil)
        #expect(manager.dailyEnergy.count == 7)
        #expect(manager.dailyEnergy.allSatisfy { !$0.hasSamples })
        #expect(manager.authorizationErrorMessage == nil)
        #expect(manager.sleepErrorMessage == nil)
        #expect(manager.energyErrorMessage == nil)
        #expect(provider.sleepWindows == [DateInterval(start: manager.windows.sleepStart, end: manager.windows.sleepEnd)])
        #expect(provider.energyWindows == [manager.windows])
    }

    @Test
    func saveBeforeLoadingCallsProviderAndRefreshesTheScreen() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.sleepResult = 7.5 * 3_600
        let calendar = try calendar()
        provider.energyResult = [DailyEnergy(date: calendar.startOfDay(for: referenceDate), kilocalories: 120)]
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })
        #expect(!manager.hasLoaded)

        await manager.saveSampleWorkout()

        let saved = try #require(manager.savedWorkout)
        #expect(provider.saveActivities.count == 1)
        #expect(saved.endDate == referenceDate)
        #expect(saved.energyKilocalories == 120)
        #expect(manager.workoutErrorMessage == nil)
        #expect(manager.workoutStatusMessage?.contains("Open Health to verify") == true)
        #expect(!manager.isSavingWorkout)
        #expect(manager.hasLoaded)
        #expect(manager.sleepDuration == 7.5 * 3_600)
        #expect(manager.dailyEnergy.first?.kilocalories == 120)
        #expect(provider.authorizationRequests == 1)
        #expect(provider.sleepWindows.count == 1)
        #expect(provider.energyWindows.count == 1)
    }

    @Test
    func failedSaveRetriesTheSameIdentityAndDatesAndSuppressesLaterDuplicates() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.saveError = .save
        let calendar = try calendar()
        var currentDate = referenceDate
        let manager = RecoveryHealthManager(provider: provider, now: { currentDate }, calendar: { calendar })

        await manager.saveSampleWorkout()

        #expect(manager.savedWorkout == nil)
        #expect(manager.workoutErrorMessage == FakeRecoveryError.save.localizedDescription)
        #expect(manager.workoutStatusMessage == nil)
        #expect(!manager.isSavingWorkout)
        #expect(provider.authorizationRequests == 0)
        let firstAttempt = try #require(provider.saveActivities.first)

        currentDate = currentDate.addingTimeInterval(3_600)
        provider.saveError = nil
        await manager.saveSampleWorkout()

        #expect(provider.saveActivities.count == 2)
        #expect(provider.saveActivities[1] == firstAttempt)
        #expect(manager.savedWorkout?.endDate == referenceDate)
        #expect(manager.windows.energyEnd == currentDate)
        #expect(manager.workoutErrorMessage == nil)
        #expect(manager.workoutStatusMessage != nil)

        await manager.saveSampleWorkout()
        #expect(provider.saveActivities.count == 2)
        #expect(provider.authorizationRequests == 1)
    }

    @Test
    func repeatedTapWhileSavingDoesNotStartAnotherWrite() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.suspendSave = true
        let calendar = try calendar()
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })
        let firstSave = Task { await manager.saveSampleWorkout() }
        await provider.waitUntilSaveStarted()

        #expect(manager.isSavingWorkout)
        await manager.saveSampleWorkout()
        #expect(provider.saveActivities.count == 1)

        provider.finishSuspendedSave()
        await firstSave.value
        #expect(manager.savedWorkout != nil)
        #expect(!manager.isSavingWorkout)
        #expect(provider.saveActivities.count == 1)
    }

    @Test
    func saveDuringPendingReadQueuesANewRefreshAndUpdatesEnergy() async throws {
        let provider = FakeRecoveryHealthProvider()
        provider.suspendFirstSleepRead = true
        let calendar = try calendar()
        let day = calendar.startOfDay(for: referenceDate)
        provider.energyResult = [DailyEnergy(date: day, kilocalories: 10)]
        let manager = RecoveryHealthManager(provider: provider, now: { referenceDate }, calendar: { calendar })
        let firstRefresh = Task { await manager.refresh() }

        // Hold sleep pending while the first energy query completes with its pre-save snapshot.
        await provider.waitUntilSleepReadStarted()
        await provider.waitUntilEnergyReadStarted()
        #expect(manager.isLoading)
        provider.energyResult = [DailyEnergy(date: day, kilocalories: 130)]

        await manager.saveSampleWorkout()
        // Additional refresh requests during the pending pass should share one follow-up pass.
        await manager.refresh()
        #expect(manager.savedWorkout != nil)
        #expect(provider.energyWindows.count == 1)
        #expect(manager.isLoading)

        provider.finishSuspendedSleepRead()
        await firstRefresh.value

        #expect(provider.saveActivities.count == 1)
        #expect(provider.authorizationRequests == 2)
        #expect(provider.sleepWindows.count == 2)
        #expect(provider.energyWindows.count == 2)
        #expect(manager.dailyEnergy == [DailyEnergy(date: day, kilocalories: 130)])
        #expect(manager.hasLoaded)
        #expect(!manager.isLoading)
        #expect(!manager.isSavingWorkout)
        #expect(manager.workoutErrorMessage == nil)
    }
}

private enum FakeRecoveryError: String, LocalizedError {
    case authorization = "The authorization request failed."
    case sleep = "The sleep query failed."
    case energy = "The energy query failed."
    case save = "The workout write failed."

    var errorDescription: String? { rawValue }
}

@MainActor
private final class FakeRecoveryHealthProvider: RecoveryHealthProviding {
    var authorizationError: FakeRecoveryError?
    var sleepError: FakeRecoveryError?
    var energyError: FakeRecoveryError?
    var saveError: FakeRecoveryError?
    var sleepResult: TimeInterval?
    var energyResult: [DailyEnergy]?
    var suspendSave = false
    var suspendFirstSleepRead = false
    private(set) var authorizationRequests = 0
    private(set) var sleepWindows: [DateInterval] = []
    private(set) var energyWindows: [RecoveryDateWindows] = []
    private(set) var saveActivities: [SampleWorkoutActivity] = []
    private var saveStarted: CheckedContinuation<Void, Never>?
    private var suspendedSave: CheckedContinuation<Void, Never>?
    private var sleepReadStarted: CheckedContinuation<Void, Never>?
    private var energyReadStarted: CheckedContinuation<Void, Never>?
    private var suspendedSleepRead: CheckedContinuation<Void, Never>?

    func requestReadAuthorization() async throws {
        authorizationRequests += 1
        if let authorizationError { throw authorizationError }
    }

    func readSleep(in window: DateInterval) async throws -> TimeInterval? {
        sleepWindows.append(window)
        sleepReadStarted?.resume()
        sleepReadStarted = nil
        if suspendFirstSleepRead && sleepWindows.count == 1 {
            await withCheckedContinuation { suspendedSleepRead = $0 }
        }
        if let sleepError { throw sleepError }
        return sleepResult
    }

    func readEnergy(windows: RecoveryDateWindows, calendar: Calendar) async throws -> [DailyEnergy] {
        energyWindows.append(windows)
        energyReadStarted?.resume()
        energyReadStarted = nil
        if let energyError { throw energyError }
        return energyResult ?? RecoveryDateWindowProvider.energyDays(now: windows.energyEnd, calendar: calendar)
            .map { DailyEnergy(date: $0, kilocalories: 0, hasSamples: false) }
    }

    func saveSampleWorkout(_ activity: SampleWorkoutActivity) async throws -> SampleWorkoutReceipt {
        saveActivities.append(activity)
        saveStarted?.resume()
        saveStarted = nil
        if suspendSave {
            await withCheckedContinuation { suspendedSave = $0 }
        }
        if let saveError { throw saveError }
        return SampleWorkoutReceipt(id: activity.id, activity: activity)
    }

    func waitUntilSaveStarted() async {
        guard saveActivities.isEmpty else { return }
        await withCheckedContinuation { saveStarted = $0 }
    }

    func finishSuspendedSave() {
        suspendedSave?.resume()
        suspendedSave = nil
    }

    func waitUntilSleepReadStarted() async {
        guard sleepWindows.isEmpty else { return }
        await withCheckedContinuation { sleepReadStarted = $0 }
    }

    func waitUntilEnergyReadStarted() async {
        guard energyWindows.isEmpty else { return }
        await withCheckedContinuation { energyReadStarted = $0 }
    }

    func finishSuspendedSleepRead() {
        suspendedSleepRead?.resume()
        suspendedSleepRead = nil
    }
}
