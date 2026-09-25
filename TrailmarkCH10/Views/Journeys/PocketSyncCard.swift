import SwiftUI
import TrailMarkCH10Core

struct PocketSyncCard: View {
    let viewModel: PocketSyncViewModel
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.statusText).font(.subheadline)
                if let summary = viewModel.summary {
                    Text("Latest watch activity: \(summary.activityDate.formatted(date: .abbreviated, time: .shortened)) · \(summary.durationText)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("The summary can arrive before the activity or its memos. Saved items appear below and in Journal.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = viewModel.errorMessage {
                    TrailmarkNotice(title: "Sync needs attention", message: error, systemImage: "exclamationmark.triangle", tint: TrailmarkTheme.clay)
                }
                Button(action: { viewModel.retry() }) {
                    if viewModel.isWorking { ProgressView("Saving received items…") }
                    else { Label(viewModel.errorMessage == nil ? "Check sync" : "Retry sync", systemImage: "arrow.triangle.2.circlepath") }
                }
                .buttonStyle(TrailmarkSecondaryButtonStyle())
                .disabled(viewModel.isWorking)
            }
            .padding(.top, 12)
        } label: {
            Label(viewModel.errorMessage == nil ? "From your Apple Watch" : "Watch sync needs attention", systemImage: viewModel.errorMessage == nil ? "applewatch" : "exclamationmark.circle")
                .font(.subheadline.weight(.semibold))
        }
        .trailmarkCard()
        .onChange(of: viewModel.errorMessage, initial: true) { _, error in
            if error != nil { isExpanded = true }
        }
        .trailmarkErrorFeedback(viewModel.errorMessage)
    }
}
