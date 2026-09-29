#if os(iOS) || os(watchOS)
import CoreMotion
import Foundation

/// Foreground, opt-in motion sampling with no HealthKit or phone dependency.
/// One service is retained at the app composition root, giving the app one manager.
@MainActor
public final class MotionService: MotionProviding {
    public let availability: MotionAvailability
    public var onSnapshot: (@MainActor @Sendable (MotionSnapshot) -> Void)?
    public var onError: (@MainActor @Sendable (String) -> Void)?

    /// Requested sensor delivery rate; actual sample timestamps govern the window.
    public static let samplingInterval: TimeInterval = 0.2
    public static let displayInterval: TimeInterval = 1
    public static let windowDuration: TimeInterval = 1
    /// Hysteresis avoids rapidly alternating labels near a single threshold.
    public static let movingThresholdG = 0.08
    public static let stillThresholdG = 0.04

    private let resources: MotionResources
    private var generation = 0
    private var isRunning = false
    private var lastReceiptUptime: TimeInterval = 0
    private var hasPublishedReading = false
    private var watchdog: Task<Void, Never>?

    public init() {
        resources = MotionResources()
        #if targetEnvironment(simulator)
        availability = .simulator
        #else
        availability = resources.manager.isDeviceMotionAvailable ? .available : .unavailable
        #endif
    }

    deinit { watchdog?.cancel() }

    public func start() throws {
        guard !isRunning else { return }
        guard availability == .available else {
            throw MotionServiceError.unavailable(availability.explanation ?? "Motion is unavailable.")
        }
        stop()
        isRunning = true
        let currentGeneration = generation
        lastReceiptUptime = ProcessInfo.processInfo.systemUptime
        hasPublishedReading = false
        resources.manager.deviceMotionUpdateInterval = Self.samplingInterval
        // This accumulator is owned by the dedicated, serial Core Motion queue.
        // Only its much less frequent presentation results cross MainActor.
        let accumulator = MotionWindowAccumulator(
            windowDuration: Self.windowDuration,
            displayInterval: Self.displayInterval,
            movingThresholdG: Self.movingThresholdG,
            stillThresholdG: Self.stillThresholdG
        )

        // Core Motion uses its own serial operation queue. Only scalar, Sendable
        // values cross to MainActor, which owns all mutable aggregation state.
        resources.manager.startDeviceMotionUpdates(to: resources.queue) { @Sendable [weak self] motion, error in
            if let error {
                let message = Self.message(for: error as NSError)
                Task { @MainActor [weak self] in
                    self?.fail(message, generation: currentGeneration)
                }
                return
            }
            guard let motion else { return }
            let acceleration = motion.userAcceleration
            let squaredMagnitude = acceleration.x * acceleration.x
                + acceleration.y * acceleration.y + acceleration.z * acceleration.z
            guard let reading = accumulator.append(squaredMagnitude: squaredMagnitude,
                                                   timestamp: motion.timestamp) else { return }
            Task { @MainActor [weak self] in
                self?.receive(reading, generation: currentGeneration)
            }
        }

        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard let self, self.isRunning, self.generation == currentGeneration else { return }
                let silence = ProcessInfo.processInfo.systemUptime - self.lastReceiptUptime
                let timeout: TimeInterval = self.hasPublishedReading ? 3 : 8
                if silence > timeout {
                    self.fail("No motion samples arrived. Keep the app open on your watch and try again.",
                              generation: currentGeneration)
                    return
                }
            }
        }
    }

    public func stop() {
        generation += 1
        isRunning = false
        watchdog?.cancel()
        watchdog = nil
        resources.manager.stopDeviceMotionUpdates()
        resources.queue.cancelAllOperations()
        hasPublishedReading = false
    }

    private func receive(_ reading: MotionWindowReading, generation: Int) {
        guard isRunning, generation == self.generation else { return }
        lastReceiptUptime = ProcessInfo.processInfo.systemUptime
        hasPublishedReading = true
        onSnapshot?(MotionSnapshot(
            accelerationRMSG: reading.rms,
            movement: reading.movement,
            sampleCount: reading.sampleCount,
            measuredAt: .now
        ))
    }

    private func fail(_ message: String, generation: Int) {
        guard isRunning, generation == self.generation else { return }
        stop()
        onError?(message)
    }

    private nonisolated static func message(for error: NSError) -> String {
        if error.domain == CMErrorDomain,
           error.code == Int(CMErrorNotAuthorized.rawValue)
            || error.code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
            return "Motion access is off. Check Motion & Fitness permissions in Settings, then try again."
        }
        return "Motion stopped: \(error.localizedDescription)"
    }
}

/// Immutable, Sendable result handed from the sensor queue to presentation.
private struct MotionWindowReading: Sendable {
    let rms: Double
    let movement: MotionMovement
    let sampleCount: Int
}

/// Access is confined to MotionResources.queue, which executes one operation at
/// a time. Each capture owns a fresh instance, so old callbacks cannot affect
/// a later run; MainActor also checks the generation on delivery.
private final class MotionWindowAccumulator: @unchecked Sendable {
    private let windowDuration: TimeInterval
    private let displayInterval: TimeInterval
    private let movingThresholdG: Double
    private let stillThresholdG: Double
    private var samples: [(timestamp: TimeInterval, squaredMagnitude: Double)] = []
    private var firstTimestamp: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var lastPublishedTimestamp: TimeInterval?
    private var movement: MotionMovement = .still

    init(windowDuration: TimeInterval, displayInterval: TimeInterval,
         movingThresholdG: Double, stillThresholdG: Double) {
        self.windowDuration = windowDuration
        self.displayInterval = displayInterval
        self.movingThresholdG = movingThresholdG
        self.stillThresholdG = stillThresholdG
    }

    func append(squaredMagnitude: Double, timestamp: TimeInterval) -> MotionWindowReading? {
        guard squaredMagnitude.isFinite, timestamp.isFinite,
              timestamp > (lastTimestamp ?? -.infinity) else { return nil }
        lastTimestamp = timestamp
        if firstTimestamp == nil { firstTimestamp = timestamp }
        samples.append((timestamp, squaredMagnitude))
        samples.removeAll { $0.timestamp < timestamp - windowDuration }

        // Warm up for a full second and publish only at the display cadence.
        guard let firstTimestamp, timestamp - firstTimestamp >= windowDuration,
              samples.count >= 2,
              timestamp - (lastPublishedTimestamp ?? -.infinity) >= displayInterval else { return nil }
        let rms = sqrt(samples.reduce(0) { $0 + $1.squaredMagnitude } / Double(samples.count))
        if rms >= movingThresholdG { movement = .moving }
        else if rms <= stillThresholdG { movement = .still }
        lastPublishedTimestamp = timestamp
        return MotionWindowReading(rms: rms, movement: movement, sampleCount: samples.count)
    }
}

private enum MotionServiceError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case let .unavailable(message): message }
    }
}

/// Resources have a non-actor owner so deallocation also stops the sensor.
/// During use, only MotionService on MainActor accesses the manager; the queue
/// exclusively delivers callbacks and never mutates shared application state.
private final class MotionResources {
    let manager = CMMotionManager()
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "TrailMark.Motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    deinit {
        manager.stopDeviceMotionUpdates()
        queue.cancelAllOperations()
    }
}
#endif
