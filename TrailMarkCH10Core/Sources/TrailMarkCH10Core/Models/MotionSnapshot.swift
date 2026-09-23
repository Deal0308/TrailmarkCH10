import Foundation

/// A short, in-memory measurement of movement at the device, in units of gravity.
/// This is a wrist-movement heuristic, not an activity classifier or step counter.
public struct MotionSnapshot: Equatable, Sendable {
    public let accelerationRMSG: Double
    public let movement: MotionMovement
    public let sampleCount: Int
    public let measuredAt: Date

    public init(
        accelerationRMSG: Double,
        movement: MotionMovement,
        sampleCount: Int,
        measuredAt: Date
    ) {
        self.accelerationRMSG = accelerationRMSG.isFinite ? max(0, accelerationRMSG) : 0
        self.movement = movement
        self.sampleCount = max(0, sampleCount)
        self.measuredAt = measuredAt
    }

    public var accelerationText: String {
        accelerationRMSG.formatted(.number.precision(.fractionLength(2)))
    }
}

public enum MotionMovement: String, Sendable {
    case still = "Still"
    case moving = "Moving"
}

public enum MotionAvailability: Sendable {
    case available
    case simulator
    case unavailable

    public var explanation: String? {
        switch self {
        case .available: nil
        case .simulator: "Motion needs a physical Apple Watch. You can still explore every page here."
        case .unavailable: "Device motion is unavailable on this device."
        }
    }
}

public enum MotionPhase: Sendable {
    case idle
    case starting
    case measuring
    case unavailable
    case failed
}
