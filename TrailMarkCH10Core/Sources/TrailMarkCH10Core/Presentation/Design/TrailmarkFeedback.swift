#if os(iOS) || os(watchOS)
import SwiftUI

/// Persistent, dismissible confirmation. It never covers the screen's controls.
public struct TrailmarkFeedback: View {
    private let feedback: UserFeedback
    private let dismiss: () -> Void

    public init(_ feedback: UserFeedback, dismiss: @escaping () -> Void) {
        self.feedback = feedback
        self.dismiss = dismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TrailmarkNotice(title: feedback.title, message: feedback.message, systemImage: "checkmark.circle.fill")
                .accessibilityElement(children: .combine)
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss confirmation")
        }
        .task(id: feedback.id) {
            AccessibilityNotification.Announcement("\(feedback.title). \(feedback.message)").post()
        }
    }
}

private struct TrailmarkErrorFeedback: ViewModifier {
    let message: String?
    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.error, trigger: message) { _, next in next != nil }
            .onChange(of: message) { _, next in
                if let next { AccessibilityNotification.Announcement(next).post() }
            }
    }
}

public extension View {
    func trailmarkErrorFeedback(_ message: String?) -> some View {
        modifier(TrailmarkErrorFeedback(message: message))
    }
}
#endif
