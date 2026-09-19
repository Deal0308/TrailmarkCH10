import Foundation

/// Presentation state for a single-metric screen, derived from the existing shared view model.
/// No second manager, duplicated query, or watch-local model is introduced.
public extension TodayViewModel {
    var stepHeadlineText: String {
        guard !isLoading, let steps = metrics?.steps else { return "—" }
        return steps.formatted(.number.precision(.fractionLength(0)))
    }

    var stepAccessibilityValue: String {
        if isLoading { return "Updating" }
        guard let steps = metrics?.steps else { return "Unavailable" }
        return "\(steps.formatted(.number.precision(.fractionLength(0)))) steps"
    }

    var stepStatusText: String {
        if isLoading || !hasCompletedInitialLoad { return "Updating Health…" }
        if errorMessage != nil { return "Health unavailable" }
        guard let metrics, metrics.steps != nil else { return "No step data available" }
        return "Updated \(metrics.queriedAt.formatted(date: .omitted, time: .shortened))"
    }

    var stepActionTitle: String {
        if isLoading { return "Updating…" }
        return errorMessage == nil ? "Refresh" : "Retry"
    }

    var stepExplanation: String? {
        if let errorMessage { return errorMessage }
        guard hasCompletedInitialLoad, !isLoading, metrics?.steps == nil else { return nil }
        return "Steps may not be recorded, synced, or shared. Review Health access on your devices."
    }
}
