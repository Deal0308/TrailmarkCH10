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
    public static let samplingInterval: TimeInterval = 0.1
    public static let displayInterval: TimeInterval = 0.5
    public static let windowDuration: TimeInterval = 1
    /// Hysteresis avoids rapidly alternating labels near a single threshold.
    public static let movingThresholdG = 0.08
    public static let stillThresholdG = 0.04

    private let resources: MotionResources
    private var generation = 0
    private var isRunning = false
    private var samples: [(timestamp: TimeInterval, squaredMagnitude: Double)] = []
    private var firstSampleTimestamp: TimeInterval?
    private var lastSampleTimestamp: TimeInterval?
    private var lastPublishedTimestamp: TimeInterval?
    private var lastReceiptUptime: TimeInterval = 0
    private var movement: MotionMovement = .still
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
        resources.manager.deviceMotionUpdateInterval = Self.samplingInterval

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
            let timestamp = motion.timestamp
            Task { @MainActor [weak self] in
                self?.receive(
                    squaredMagnitude: squaredMagnitude,
                    timestamp: timestamp,
                    generation: currentGeneration
                )
            }
        }

        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard let self, self.isRunning, self.generation == currentGeneration else { return }
                let silence = ProcessInfo.processInfo.systemUptime - self.lastReceiptUptime
                let timeout: TimeInterval = self.lastSampleTimestamp == nil ? 8 : 3
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
        samples.removeAll(keepingCapacity: true)
        firstSampleTimestamp = nil
        lastSampleTimestamp = nil
        lastPublishedTimestamp = nil
        movement = .still
    }

    private func receive(squaredMagnitude: Double, timestamp: TimeInterval, generation: Int) {
        guard isRunning, generation == self.generation,
              squaredMagnitude.isFinite, timestamp.isFinite,
              timestamp > (lastSampleTimestamp ?? -.infinity) else { return }
        lastSampleTimestamp = timestamp
        lastReceiptUptime = ProcessInfo.processInfo.systemUptime
        if firstSampleTimestamp == nil { firstSampleTimestamp = timestamp }
        samples.append((timestamp, squaredMagnitude))
        samples.removeAll { $0.timestamp < timestamp - Self.windowDuration }

        // Warm up for a full second; do not label one noisy sample as movement.
        guard let firstSampleTimestamp, timestamp - firstSampleTimestamp >= Self.windowDuration,
              samples.count >= 2,
              timestamp - (lastPublishedTimestamp ?? -.infinity) >= Self.displayInterval else { return }
        let rms = sqrt(samples.reduce(0) { $0 + $1.squaredMagnitude } / Double(samples.count))
        if rms >= Self.movingThresholdG { movement = .moving }
        else if rms <= Self.stillThresholdG { movement = .still }
        lastPublishedTimestamp = timestamp
        onSnapshot?(MotionSnapshot(
            accelerationRMSG: rms,
            movement: movement,
            sampleCount: samples.count,
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
