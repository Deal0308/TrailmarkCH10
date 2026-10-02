#if os(iOS)
import Foundation
import UniformTypeIdentifiers

public enum MediaLibraryService {
    /// The picker grants access only to the selected item; no broad Photos authorization.
    static func stageVideo(from provider: NSItemProvider, completion: @escaping @MainActor @Sendable (Result<URL, Error>) -> Void) {
        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            let result: Result<URL, Error>
            do {
                if let error { throw error }
                guard let url else { throw LibraryError.missingVideo }
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                // The provider's URL expires when this callback returns, so copy it here.
                try FileManager.default.copyItem(at: url, to: destination)
                result = .success(destination)
            } catch { result = .failure(error) }
            Task { @MainActor in completion(result) }
        }
    }
}
private enum LibraryError: LocalizedError {
    case missingVideo
    var errorDescription: String? { "The selected video could not be loaded. Download it in Photos and try again." }
}
#endif
