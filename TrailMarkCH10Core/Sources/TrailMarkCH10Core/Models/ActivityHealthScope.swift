/// Selects the data a screen needs without duplicating its HealthKit service.
public enum ActivityHealthScope: Sendable {
    case allMetrics
    case stepsOnly
}
