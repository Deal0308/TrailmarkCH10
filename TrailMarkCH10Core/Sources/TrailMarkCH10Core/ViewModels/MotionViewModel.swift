#if os(iOS) || os(watchOS)
import Foundation
import Observation

/// Presentation state and user actions; sensor access belongs to MotionService.
@MainActor
@Observable
public final class MotionViewModel {
    public private(set) var snapshot: MotionSnapshot?
    public private(set) var phase: MotionPhase = .idle
    public private(set) var errorMessage: String?
    public let availability: MotionAvailability

    @ObservationIgnored private let service: any MotionProviding

    public init(service: any MotionProviding = MotionService()) {
        self.service = service
        availability = service.availability
        if availability != .available { phase = .unavailable }
        service.onSnapshot = { [weak self] snapshot in
            guard let self, self.isRunning else { return }
            self.snapshot = snapshot
            self.phase = .measuring
        }
        service.onError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
            self.phase = .failed
        }
    }

    public var isRunning: Bool { phase == .starting || phase == .measuring }
    public var canStart: Bool { availability == .available && !isRunning }
    public var movementText: String {
        if phase == .starting { return "Measuring…" }
        if phase == .measuring { return snapshot?.movement.rawValue ?? "Measuring…" }
        return snapshot == nil ? "Ready" : "Stopped"
    }
    public var accelerationText: String { snapshot?.accelerationText ?? "—" }
    public var statusText: String {
        switch phase {
        case .idle:
            snapshot == nil ? "Start, then gently move your wrist." : "Measurement stopped. Tap Start to measure again."
        case .starting: "Gathering a second of motion…"
        case .measuring: "Wrist movement · last 1 second"
        case .unavailable: availability.explanation ?? "Motion is unavailable."
        case .failed: errorMessage ?? "Motion could not start. Try again."
        }
    }
    public var accessibilityValue: String {
        guard let snapshot else { return statusText }
        let label = isRunning ? snapshot.movement.rawValue : "Last measurement"
        return "\(label). \(snapshot.accelerationText) g root mean square acceleration."
    }

    public func start() {
        guard canStart else { return }
        snapshot = nil
        errorMessage = nil
        phase = .starting
        do { try service.start() }
        catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    /// Returning to the page never resumes sampling without another explicit Start.
    public func stop() {
        service.stop()
        if isRunning { phase = .idle }
    }
}
#endif
