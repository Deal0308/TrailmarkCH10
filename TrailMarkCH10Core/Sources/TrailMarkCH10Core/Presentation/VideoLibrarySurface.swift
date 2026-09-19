#if os(iOS)
import PhotosUI
import SwiftUI

public struct VideoLibrarySurface: UIViewControllerRepresentable {
    private let onPicked: @MainActor @Sendable (URL) -> Void
    private let onError: @MainActor @Sendable (String) -> Void
    private let onCancel: @MainActor @Sendable () -> Void
    public init(onPicked: @escaping @MainActor @Sendable (URL) -> Void, onError: @escaping @MainActor @Sendable (String) -> Void, onCancel: @escaping @MainActor @Sendable () -> Void) {
        self.onPicked = onPicked; self.onError = onError; self.onCancel = onCancel
    }
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    public func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    public func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: VideoLibrarySurface
        init(parent: VideoLibrarySurface) { self.parent = parent }
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else { parent.onCancel(); return }
            // Dismissal happens in the app after the selected item is safely staged.
            MediaLibraryService.stageVideo(from: result.itemProvider) { [parent] result in
                switch result {
                case let .success(url): parent.onPicked(url)
                case let .failure(error): parent.onError(error.localizedDescription)
                }
            }
        }
    }
}
#endif
