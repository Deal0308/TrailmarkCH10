import Foundation

enum MediaFileService {
    /// Temporary capture/picker files are disposable after the persistent copy commits.
    static func removeTemporaryFile(_ url: URL) {
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(temporary.hasSuffix("/") ? temporary : temporary + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
