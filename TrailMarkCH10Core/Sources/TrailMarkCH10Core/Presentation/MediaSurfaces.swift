#if os(iOS)
import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Rendering adapters only. Recording, file access, and playback lifecycle stay in services/view models.
public struct MediaPlayerSurface: View {
    private let service: MediaPlaybackService
    public init(service: MediaPlaybackService) { self.service = service }
    public var body: some View { VideoPlayer(player: service.player) }
}

public struct MemoThumbnailSurface: View {
    private let data: Data?
    private let type: JournalMediaType
    public init(data: Data?, type: JournalMediaType) { self.data = data; self.type = type }
    public var body: some View {
        Group {
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: type == .video ? "video.fill" : "mic.fill").font(.title2).foregroundStyle(type == .video ? .orange : .blue) }
        }
        .accessibilityHidden(true)
    }
}

public struct CameraPreviewSurface: UIViewRepresentable {
    private let service: MediaCaptureService
    public init(service: MediaCaptureService) { self.service = service }
    public func makeUIView(context: Context) -> CameraLayerView {
        let view = CameraLayerView()
        view.isAccessibilityElement = false
        view.previewLayer?.videoGravity = .resizeAspectFill
        view.previewLayer?.session = service.previewSession
        return view
    }
    public func updateUIView(_ view: CameraLayerView, context: Context) { view.previewLayer?.session = service.previewSession }
    public final class CameraLayerView: UIView {
        public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }
}
#endif
