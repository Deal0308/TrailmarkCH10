import SwiftUI
import TrailMarkCH10Core

struct TrailmarkHelpView: View {
    @State private var viewModel = AppHelpViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrailmarkSectionHeader(eyebrow: "MAKE YOURSELF AT HOME", title: "A little guidance.", subtitle: "Capture the day at your own pace.")
                    help("Start with a journey", symbol: "map", message: "In Journeys, start a named walk. Keep Trailmark open to record the route. Add a voice or video memo in Journal; it will attach to that journey. Finish when you’re ready.")
                    help("Keep a moment", symbol: "mic", message: "Record a memo without starting a journey if you prefer. Stop & save keeps it in Journal. Tap a saved memo to play it. Search by voice, video, watch, or date.")
                    help("Bring your watch along", symbol: "applewatch", message: "Swipe vertically or turn the Digital Crown between Home, Memos, Vitals, and Motion. End a workout and save a memo to queue them for iPhone. Check each memo’s transfer status on your watch. Delivery may take time; the apps do not both need to stay open.")
                    help("Health is your choice", symbol: "heart", message: "Enable Health in Vitals on Apple Watch when you want readings. In the Health app on iPhone, use your profile to manage Trailmark’s access under Apps. A dash means no readable sample, which may be missing, syncing, or not shared. Your Journal and Journeys remain usable.")
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Camera, microphone & location", systemImage: "hand.raised").font(.headline)
                        Text("Trailmark asks when you use a feature. If access was declined, open Settings to change it. Precise Location improves route recording; you can still save memos without a location.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Open Trailmark settings", systemImage: "gearshape") { Task { await viewModel.openSettings() } }
                            .buttonStyle(TrailmarkSecondaryButtonStyle())
                        if let error = viewModel.errorMessage { Text(error).font(.footnote) }
                    }
                    .trailmarkCard()
                    help("Your recordings stay yours", symbol: "externaldrive", message: "Journeys and memos are saved on each device. Watch transfers copy them to your paired iPhone. Deleting a memo removes its file on that device; copies on the other device stay there. You’ll be asked before deleting.")
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .trailmarkScreen()
            .navigationTitle("Trailmark help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) } }
        }
    }

    private func help(_ title: String, symbol: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            Text(message).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailmarkCard()
    }
}
