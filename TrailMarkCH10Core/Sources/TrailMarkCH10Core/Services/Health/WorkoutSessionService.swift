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
    private var isFinishing = false
    private var elapsedUpdates: Task<Void, Never>?
    #elseif os(iOS)
    private var connectionWatchdog: Task<Void, Never>?
    private var commandWatchdog: Task<Void, Never>?
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
        guard let healthStore else {
            fail("Workout sensors require an Apple Watch with Health available. You can return and use the other pages.")
            return
        }
        resetForNewWorkout(message: "Requesting Health access…")

        do {
            #if os(watchOS)
            await start(configuration: Self.walkingConfiguration())
            #elseif os(iOS)
            let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate)]
            try await healthStore.requestAuthorization(toShare: [], read: read)
            update(state: .starting, message: "Opening Trailmark Workout on Apple Watch…")
            try await healthStore.startWatchApp(toHandle: Self.walkingConfiguration())
            startConnectionWatchdog()
            #else
            fail("Live workout tracking requires iPhone or Apple Watch.")
            #endif
        } catch {
            fail(Self.message(for: error))
        }
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
        guard metrics.isActive, metrics.state != .ending else { return }
        #if os(iOS)
        send(command: .end)
        #else
        update(state: .ending, message: "Finishing workout…")
        session?.end()
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
        message: String? = nil
    ) {
        metrics = WorkoutMetrics(
            state: state ?? metrics.state,
            startedAt: startedAt ?? metrics.startedAt,
            elapsedTime: elapsedTime ?? metrics.elapsedTime,
            currentHeartRateBPM: currentHeartRate ?? metrics.currentHeartRateBPM,
            heartRateSampleDate: heartRateSampleDate ?? metrics.heartRateSampleDate,
            averageHeartRateBPM: averageHeartRate ?? metrics.averageHeartRateBPM,
            activeEnergyKilocalories: activeEnergy ?? metrics.activeEnergyKilocalories,
            statusMessage: message ?? metrics.statusMessage
        )
        onMetrics?(metrics)
        #if os(watchOS)
        sendMetricsToPhone()
        #endif
    }

    private func accept(_ received: WorkoutMetrics) {
        metrics = received
        onMetrics?(received)
        #if os(iOS)
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
        metrics = WorkoutMetrics(
            state: .failed,
            startedAt: metrics.startedAt,
            elapsedTime: metrics.elapsedTime,
            currentHeartRateBPM: metrics.currentHeartRateBPM,
            heartRateSampleDate: metrics.heartRateSampleDate,
            averageHeartRateBPM: metrics.averageHeartRateBPM,
            activeEnergyKilocalories: metrics.activeEnergyKilocalories,
            statusMessage: "Workout unavailable."
        )
        onMetrics?(metrics)
        onError?(message)
        #if os(watchOS)
        sendMetricsToPhone()
        #endif
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain, nsError.code == HKError.errorAuthorizationDenied.rawValue {
            return "Allow Trailmark to read Heart Rate and save Workouts in Health settings, then try again."
        }
        return error.localizedDescription
    }

    #if os(watchOS)
    private func start(configuration: HKWorkoutConfiguration) async {
        guard !metrics.isActive else { return }
        guard let healthStore else { fail("Health data is unavailable on this watch."); return }
        do {
            resetForNewWorkout(message: "Requesting workout and heart-rate access…")
            let share: Set<HKSampleType> = [HKObjectType.workoutType()]
            let read: Set<HKObjectType> = [
                HKQuantityType(.heartRate),
                HKQuantityType(.activeEnergyBurned)
            ]
            try await healthStore.requestAuthorization(toShare: share, read: read)
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
            do { try await session.startMirroringToCompanionDevice() }
            catch { onError?("The workout is running on Apple Watch, but iPhone mirroring is unavailable: \(error.localizedDescription)") }
        } catch {
            session = nil
            builder = nil
            fail(Self.message(for: error))
        }
    }

    private func refreshStatistics(_ types: Set<HKSampleType>) {
        guard let builder else { return }
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
        guard !isFinishing, let builder else { return }
        isFinishing = true
        elapsedUpdates?.cancel()
        elapsedUpdates = nil
        do {
            try await builder.endCollection(at: date)
            let savedWorkout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
                builder.finishWorkout { workout, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: workout) }
                }
            }
            guard savedWorkout != nil else {
                fail("Health did not confirm the workout save. Check Apple Health before recording another session.")
                session = nil
                self.builder = nil
                isFinishing = false
                return
            }
            refreshStatistics(Set([HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]))
            update(state: .completed, elapsedTime: builder.elapsedTime,
                   message: "Workout saved to Health. Heart-rate values appear only when samples were collected.")
        } catch { fail("The workout could not be saved: \(error.localizedDescription)") }
        session = nil
        self.builder = nil
        isFinishing = false
    }

    private func sendMetricsToPhone() {
        guard session?.state == .running || session?.state == .paused || metrics.state == .completed || metrics.state == .failed,
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
        session = mirroredSession
        mirroredSession.delegate = self
        update(state: .starting, startedAt: mirroredSession.startDate,
               message: "Connecting to Apple Watch heart-rate tracking…")
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
            guard let self else { return }
            switch toState {
            case .running:
                update(state: .running, startedAt: workoutSession.startDate ?? date,
                       message: "Tracking heart rate on Apple Watch.")
                #if os(watchOS)
                startElapsedUpdates()
                #endif
            case .paused:
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
                if metrics.state != .completed {
                    update(state: .ending, message: "Waiting for Apple Watch to save the workout…")
                }
                #endif
            case .prepared:
                update(state: .starting, message: "Workout sensors prepared.")
            case .notStarted:
                break
            case .stopped:
                update(state: .ending, message: "Finishing workout…")
            @unknown default:
                break
            }
        }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.fail(Self.message(for: error)) }
    }

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for value in data {
                guard let message = try? JSONDecoder().decode(WorkoutRemoteMessage.self, from: value) else { continue }
                #if os(watchOS)
                switch message.command {
                case .pause: session?.pause()
                case .resume: session?.resume()
                case .end: end()
                case nil: break
                }
                #else
                if let metrics = message.metrics { accept(metrics) }
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
        Task { @MainActor [weak self] in self?.refreshStatistics(collectedTypes) }
    }

    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        Task { @MainActor [weak self] in
            self?.update(elapsedTime: workoutBuilder.elapsedTime)
        }
    }
}
#endif

#endif
