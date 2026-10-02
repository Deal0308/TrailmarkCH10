#if os(iOS) || os(watchOS)
import Foundation
import HealthKit

/// Runs the primary sensor session on Apple Watch and mirrors its model to iPhone.
/// HealthKit types never escape this package boundary.
@MainActor
public final class WorkoutSessionService: NSObject {
    public var onMetrics: ((WorkoutMetrics) -> Void)?
    public var onError: ((String) -> Void)?
    public var onCommandPending: ((Bool) -> Void)?

    private let healthStore: HKHealthStore?
    private var session: HKWorkoutSession?
    private var metrics: WorkoutMetrics = .idle

    #if os(watchOS)
    private var builder: HKLiveWorkoutBuilder?
    private var isStarting = false
    private var isFinishing = false
    private var elapsedUpdates: Task<Void, Never>?
    private var finalDeliveryTimeout: Task<Void, Never>?
    #elseif os(iOS)
    private var connectionWatchdog: Task<Void, Never>?
    private var commandWatchdog: Task<Void, Never>?
    private var saveConfirmationWatchdog: Task<Void, Never>?
    private var pendingCommand: WorkoutRemoteCommand?
    #endif

    public override init() {
        #if os(watchOS) && targetEnvironment(simulator)
        healthStore = nil
        #else
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
        #endif
        super.init()

        #if os(iOS)
        healthStore?.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            Task { @MainActor [weak self] in self?.attachMirroredSession(mirroredSession) }
        }
        #elseif os(watchOS)
        WorkoutLaunchCoordinator.shared.bind { [weak self] configuration in
            Task { @MainActor [weak self] in await self?.start(configuration: configuration) }
        }
        #endif
    }

    public func start() async {
        guard !metrics.isActive, metrics.state != .requestingAuthorization else { return }
        #if os(watchOS)
        await start(configuration: Self.walkingConfiguration())
        #else
        guard let healthStore else {
            fail("Workout sensors require an Apple Watch with Health available. You can return and use the other pages.")
            return
        }
        resetForNewWorkout(message: "Requesting Health access…")

        do {
            let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate)]
            try await healthStore.requestAuthorization(toShare: [], read: read)
            update(state: .starting, message: "Opening Trailmark Workout on Apple Watch…")
            try await healthStore.startWatchApp(toHandle: Self.walkingConfiguration())
            startConnectionWatchdog()
        } catch {
            fail(Self.message(for: error))
        }
        #endif
    }

    /// Resample presentation after returning to the app. The session and live
    /// builder keep collecting independently of scene/view visibility.
    public func refreshCurrentWorkout() {
        #if os(watchOS)
        guard metrics.state == .running || metrics.state == .paused else { return }
        refreshStatistics(Set([HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]))
        #endif
    }

    public func pause() {
        guard metrics.state == .running else { return }
        #if os(iOS)
        send(command: .pause)
        #else
        session?.pause()
        #endif
    }

    public func resume() {
        guard metrics.state == .paused else { return }
        #if os(iOS)
        send(command: .resume)
        #else
        session?.resume()
        #endif
    }

    public func end() {
        guard metrics.state == .running || metrics.state == .paused else { return }
        #if os(iOS)
        send(command: .end)
        #else
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        update(state: .ending, message: "Finishing workout…")
        // Stop sensors but retain workout runtime and mirroring until the save
        // and its final confirmation finish. end() exits session mode.
        session?.stopActivity(with: Date())
        #endif
    }

    private static func walkingConfiguration() -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        return configuration
    }

    private func resetForNewWorkout(message: String) {
        #if os(watchOS)
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        #elseif os(iOS)
        connectionWatchdog?.cancel()
        connectionWatchdog = nil
        saveConfirmationWatchdog?.cancel()
        saveConfirmationWatchdog = nil
        session?.delegate = nil
        session = nil
        clearPendingCommand()
        #endif
        metrics = WorkoutMetrics(state: .requestingAuthorization, statusMessage: message)
        onMetrics?(metrics)
    }

    private func update(
        state: WorkoutTrackingState? = nil,
        startedAt: Date? = nil,
        elapsedTime: TimeInterval? = nil,
        currentHeartRate: Double? = nil,
        heartRateSampleDate: Date? = nil,
        averageHeartRate: Double? = nil,
        activeEnergy: Double? = nil,
        message: String? = nil,
        mirror: Bool = true
    ) {
        metrics = WorkoutMetrics(
            state: state ?? metrics.state,
            startedAt: startedAt ?? metrics.startedAt,
            elapsedTime: elapsedTime ?? metrics.elapsedTime,
            currentHeartRateBPM: currentHeartRate ?? metrics.currentHeartRateBPM,
            heartRateSampleDate: heartRateSampleDate ?? metrics.heartRateSampleDate,
            averageHeartRateBPM: averageHeartRate ?? metrics.averageHeartRateBPM,
            activeEnergyKilocalories: activeEnergy ?? metrics.activeEnergyKilocalories,
            savedWorkout: metrics.savedWorkout,
            statusMessage: message ?? metrics.statusMessage
        )
        onMetrics?(metrics)
        #if os(watchOS)
        if mirror { sendMetricsToPhone() }
        #endif
    }

    private func accept(_ received: WorkoutMetrics) {
        metrics = received
        onMetrics?(received)
        #if os(iOS)
        if received.state == .completed || received.state == .failed {
            saveConfirmationWatchdog?.cancel()
            saveConfirmationWatchdog = nil
        }
        let confirmed = (pendingCommand == .pause && received.state == .paused)
            || (pendingCommand == .resume && received.state == .running)
            || (pendingCommand == .end && (received.state == .ending || received.state == .completed))
            || received.state == .failed
        if confirmed { clearPendingCommand() }
        #endif
    }

    private func fail(_ message: String) {
        #if os(watchOS)
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        #elseif os(iOS)
        connectionWatchdog?.cancel()
        connectionWatchdog = nil
        clearPendingCommand()
        #endif
        let failure = WorkoutMetrics(
            state: .failed,
            startedAt: metrics.startedAt,
            elapsedTime: metrics.elapsedTime,
            currentHeartRateBPM: metrics.currentHeartRateBPM,
            heartRateSampleDate: metrics.heartRateSampleDate,
            averageHeartRateBPM: metrics.averageHeartRateBPM,
            activeEnergyKilocalories: metrics.activeEnergyKilocalories,
            statusMessage: message
        )
        onError?(message)
        #if os(watchOS)
        if let session {
            isFinishing = true
            builder?.delegate = nil
            update(state: .ending, message: "Ending workout…", mirror: false)
            finishDelivering(failure, from: session)
        } else { accept(failure) }
        #else
        accept(failure)
        #endif
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain, nsError.code == HKError.errorAuthorizationDenied.rawValue {
            return "Allow Trailmark to save Workouts in Health settings. Enable Heart Rate and Active Energy access for live readings, then try again."
        }
        return error.localizedDescription
    }

    #if os(watchOS)
    private func start(configuration: HKWorkoutConfiguration) async {
        guard !metrics.isActive, !isStarting, !isFinishing, session == nil else { return }
        guard let healthStore else {
            fail("Live workouts require a physical Apple Watch with Health available. You can use the other pages in the simulator.")
            return
        }
        isStarting = true
        defer { isStarting = false }
        do {
            resetForNewWorkout(message: "Requesting workout and heart-rate access…")
            let share: Set<HKSampleType> = [
                HKObjectType.workoutType(), HKQuantityType(.heartRate),
                HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)
            ]
            let read: Set<HKObjectType> = [
                HKObjectType.workoutType(), HKQuantityType(.heartRate),
                HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)
            ]
            try await healthStore.requestAuthorization(toShare: share, read: read)
            // requestAuthorization completes the prompt; it does not mean every
            // permission was granted. Only write status is publicly observable.
            guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                fail("Allow Trailmark to save Workouts in Health settings before starting a walk. Other watch pages remain available.")
                return
            }
            update(state: .starting, message: "Starting workout sensors…")
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            self.session = session
            self.builder = builder
            session.delegate = self
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            guard self.session === session, !isFinishing else { return }
            update(startedAt: start, elapsedTime: builder.elapsedTime)
            do { try await session.startMirroringToCompanionDevice() }
            catch {
                if self.session === session, !isFinishing {
                    onError?("Your walk is recording on Apple Watch. Live iPhone display is unavailable; the finished activity can still sync later.")
                }
            }
        } catch {
            // A collection error can happen after sensors started. Explicitly
            // stop the old session so it cannot outlive this failed attempt.
            let failedSession = session
            session?.delegate = nil
            builder?.delegate = nil
            builder?.discardWorkout()
            session = nil
            builder = nil
            failedSession?.end()
            fail(Self.message(for: error))
        }
    }

    private func refreshStatistics(_ types: Set<HKSampleType>, isFinal: Bool = false) {
        guard let builder, !isFinishing || isFinal else { return }
        let heartType = HKQuantityType(.heartRate)
        let energyType = HKQuantityType(.activeEnergyBurned)
        let heartUnit = HKUnit.count().unitDivided(by: .minute())
        var current = metrics.currentHeartRateBPM
        var heartRateDate = metrics.heartRateSampleDate
        var average = metrics.averageHeartRateBPM
        var energy = metrics.activeEnergyKilocalories
        if types.contains(heartType), let statistics = builder.statistics(for: heartType) {
            current = statistics.mostRecentQuantity()?.doubleValue(for: heartUnit)
            heartRateDate = statistics.mostRecentQuantityDateInterval()?.end
            average = statistics.averageQuantity()?.doubleValue(for: heartUnit)
        }
        if types.contains(energyType) {
            energy = builder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
        update(elapsedTime: builder.elapsedTime, currentHeartRate: current,
               heartRateSampleDate: heartRateDate,
               averageHeartRate: average, activeEnergy: energy)
    }

    private func finishWorkout(at date: Date) async {
        guard !isFinishing, let builder, let session else { return }
        isFinishing = true
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        update(state: .ending, elapsedTime: builder.elapsedTime, message: "Saving your walk to Health…")
        do {
            try await builder.endCollection(at: date)
            guard self.session === session, self.builder === builder else { return }
            let savedWorkout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
                builder.finishWorkout { workout, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: workout) }
                }
            }
            guard self.session === session, self.builder === builder else { return }
            // Apple documents nil workout + nil error as successful saving while
            // locked. A receipt records that success without inventing a UUID.
            let receipt = WorkoutSaveReceipt(
                workoutID: savedWorkout?.uuid,
                startDate: savedWorkout?.startDate ?? builder.startDate ?? metrics.startedAt ?? date,
                endDate: savedWorkout?.endDate ?? date,
                duration: savedWorkout?.duration ?? builder.elapsedTime
            )
            refreshStatistics(Set([HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]), isFinal: true)
            let completed = WorkoutMetrics(
                state: .completed, startedAt: receipt.startDate, elapsedTime: receipt.duration,
                currentHeartRateBPM: metrics.currentHeartRateBPM,
                heartRateSampleDate: metrics.heartRateSampleDate,
                averageHeartRateBPM: metrics.averageHeartRateBPM,
                activeEnergyKilocalories: metrics.activeEnergyKilocalories,
                savedWorkout: receipt, statusMessage: receipt.confirmationText
            )
            finishDelivering(completed, from: session)
        } catch { fail("The workout could not be saved: \(error.localizedDescription)") }
    }

    /// Give the companion a final receipt before ending mirroring. A disconnected
    /// phone cannot hold workout runtime open indefinitely; Pocket Sync separately
    /// queues the completed activity when the final state is published.
    private func finishDelivering(_ result: WorkoutMetrics, from finishedSession: HKWorkoutSession) {
        finalDeliveryTimeout?.cancel()
        guard finishedSession.state != .ended,
              let data = try? JSONEncoder().encode(WorkoutRemoteMessage(metrics: result)) else {
            releaseSession(finishedSession, result: result)
            return
        }
        finalDeliveryTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.releaseSession(finishedSession, result: result)
        }
        finishedSession.sendToRemoteWorkoutSession(data: data) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.releaseSession(finishedSession, result: result) }
        }
    }

    private func releaseSession(_ finishedSession: HKWorkoutSession, result: WorkoutMetrics) {
        guard session === finishedSession else { return }
        finalDeliveryTimeout?.cancel()
        finalDeliveryTimeout = nil
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        finishedSession.delegate = nil
        builder?.delegate = nil
        builder = nil
        session = nil
        isFinishing = false
        if finishedSession.state != .ended { finishedSession.end() }
        accept(result)
    }

    private func sendMetricsToPhone() {
        guard session?.state == .running || session?.state == .paused || session?.state == .stopped,
              let data = try? JSONEncoder().encode(WorkoutRemoteMessage(metrics: metrics)) else { return }
        session?.sendToRemoteWorkoutSession(data: data) { _, _ in }
    }

    private func startElapsedUpdates() {
        elapsedUpdates?.cancel()
        elapsedUpdates = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let builder, metrics.state == .running else { return }
                update(elapsedTime: builder.elapsedTime)
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
            }
        }
    }
    #endif

    #if os(iOS)
    private func attachMirroredSession(_ mirroredSession: HKWorkoutSession) {
        connectionWatchdog?.cancel()
        connectionWatchdog = nil
        saveConfirmationWatchdog?.cancel()
        saveConfirmationWatchdog = nil
        clearPendingCommand()
        session?.delegate = nil
        session = mirroredSession
        mirroredSession.delegate = self
        accept(WorkoutMetrics(state: .starting, startedAt: mirroredSession.startDate,
                              statusMessage: "Connecting to Apple Watch heart-rate tracking…"))
    }

    private func send(command: WorkoutRemoteCommand) {
        guard pendingCommand == nil else { return }
        guard let session, let data = try? JSONEncoder().encode(WorkoutRemoteMessage(command: command)) else {
            onError?("Apple Watch is disconnected. The workout may still be running on your watch; reconnect and try the control again.")
            return
        }
        pendingCommand = command
        onCommandPending?(true)
        commandWatchdog = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, pendingCommand != nil else { return }
            clearPendingCommand()
            onError?("Apple Watch has not confirmed the action. Check your watch before trying again; the workout may still be running.")
        }
        session.sendToRemoteWorkoutSession(data: data) { [weak self] success, error in
            if !success {
                Task { @MainActor [weak self] in
                    self?.clearPendingCommand()
                    self?.onError?(error?.localizedDescription ?? "The workout command did not reach Apple Watch.")
                }
            }
        }
    }

    private func clearPendingCommand() {
        pendingCommand = nil
        commandWatchdog?.cancel()
        commandWatchdog = nil
        onCommandPending?(false)
    }

    private func startConnectionWatchdog() {
        connectionWatchdog?.cancel()
        connectionWatchdog = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(20)) }
            catch { return }
            guard let self, metrics.state == .starting, session == nil else { return }
            fail("Apple Watch did not connect. Make sure it is nearby, unlocked, and running Trailmark, then try again.")
        }
    }

    private func awaitFinalConfirmation(from endedSession: HKWorkoutSession) {
        clearPendingCommand()
        saveConfirmationWatchdog?.cancel()
        saveConfirmationWatchdog = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, session === endedSession, metrics.state == .ending else { return }
            update(state: .confirmationUnavailable,
                   message: "Your watch session ended, but its save confirmation did not reach this iPhone. Check Apple Watch or Health before starting another walk. Pocket Sync may still deliver the activity.")
        }
    }
    #endif
}

private enum WorkoutRemoteCommand: String, Codable, Sendable { case pause, resume, end }

private struct WorkoutRemoteMessage: Codable, Sendable {
    let metrics: WorkoutMetrics?
    let command: WorkoutRemoteCommand?
    init(metrics: WorkoutMetrics) { self.metrics = metrics; command = nil }
    init(command: WorkoutRemoteCommand) { metrics = nil; self.command = command }
}

extension WorkoutSessionService: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self, session === workoutSession else { return }
            // HealthKit can deliver queued transitions after our final data.
            guard metrics.state != .completed, metrics.state != .failed else { return }
            switch toState {
            case .running:
                guard metrics.state != .ending else { return }
                update(state: .running, startedAt: workoutSession.startDate ?? date,
                       message: "Tracking heart rate on Apple Watch.")
                #if os(watchOS)
                startElapsedUpdates()
                #endif
            case .paused:
                guard metrics.state != .ending else { return }
                #if os(watchOS)
                elapsedUpdates?.cancel()
                elapsedUpdates = nil
                if let builder { update(elapsedTime: builder.elapsedTime) }
                #endif
                update(state: .paused, message: "Workout paused.")
            case .ended:
                #if os(watchOS)
                elapsedUpdates?.cancel()
                elapsedUpdates = nil
                #endif
                #if os(watchOS)
                await finishWorkout(at: date)
                #else
                update(state: .ending, message: "The watch session ended. Check Apple Watch or Health for the saved walk; its activity can still arrive through Pocket Sync.")
                awaitFinalConfirmation(from: workoutSession)
                #endif
            case .prepared:
                update(state: .starting, message: "Workout sensors prepared.")
            case .notStarted:
                break
            case .stopped:
                update(state: .ending, message: "Finishing workout…")
                #if os(watchOS)
                await finishWorkout(at: date)
                #endif
            @unknown default:
                break
            }
        }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, session === workoutSession else { return }
            guard metrics.state != .completed else { return }
            #if os(watchOS)
            // A stopped session may report an interruption while its builder is
            // already saving. Let that operation report its actual save outcome.
            if isFinishing { return }
            #endif
            fail(Self.message(for: error))
        }
    }

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor [weak self] in
            guard let self, session === workoutSession else { return }
            for value in data {
                guard let message = try? JSONDecoder().decode(WorkoutRemoteMessage.self, from: value) else { continue }
                #if os(watchOS)
                switch message.command {
                case .pause: pause()
                case .resume: resume()
                case .end: end()
                case nil: break
                }
                #else
                if let received = message.metrics {
                    // Queued older readings must not replace the final receipt.
                    if metrics.state == .completed { continue }
                    if metrics.state == .failed,
                       received.state != .completed { continue }
                    if (workoutSession.state == .ended || metrics.state == .confirmationUnavailable),
                       received.state != .completed, received.state != .failed { continue }
                    accept(received)
                }
                #endif
            }
        }
    }
}

#if os(watchOS)
extension WorkoutSessionService: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            guard let self, builder === workoutBuilder else { return }
            refreshStatistics(collectedTypes)
        }
    }

    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        Task { @MainActor [weak self] in
            guard let self, builder === workoutBuilder, !isFinishing else { return }
            update(elapsedTime: workoutBuilder.elapsedTime)
        }
    }
}
#endif

#endif
