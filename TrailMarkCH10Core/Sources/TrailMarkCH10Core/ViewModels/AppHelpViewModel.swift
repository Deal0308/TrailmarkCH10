#if os(iOS)
import Foundation
import Observation

@MainActor
@Observable
public final class AppHelpViewModel {
    public private(set) var errorMessage: String?
    public init() {}
    public func openSettings() async {
        let opened = await AppSettingsService.open()
        errorMessage = opened ? nil : "Open the Settings app, find Trailmark, and manage its permissions there."
    }
}
#endif
