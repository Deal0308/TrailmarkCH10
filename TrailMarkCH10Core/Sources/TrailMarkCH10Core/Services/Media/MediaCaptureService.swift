#if os(iOS)
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
public final class MediaCaptureService {
    public private(set) var phase: CapturePhase = .idle
    public private(set) var errorMessage: String?
    public private(set) var recordingStartedAt: Date?
    public private(set) var result: CapturedMedia?
    @ObservationIgnored var onStarted: (() -> Void)?
    @ObservationIgnored var onFinished: (() -> Void)?
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var video: VideoRecordingWorker
    var previewSession: AVCaptureSession { video.session }

    public init() {
        video = VideoRecordingWorker()
        video.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.receive(event) }
        }
    }

    public func start(type: JournalMediaType) async {
        guard phase == .idle || phase == .failed else { return }
        phase = .preparing
        errorMessage = nil
        let token = generation
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        let camera = type == .audio ? true : await AVCaptureDevice.requestAccess(for: .video)
        guard token == generation else { return }
        guard mic && camera else {
            phase = .failed
            errorMessage = "Allow \(type == .video ? "camera and microphone" : "microphone") access in Settings to record. You can still browse saved memos."
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(type == .audio ? .record : .playAndRecord, mode: type == .audio ? .spokenAudio : .videoRecording)
            try audio.setActive(true)
            if type == .audio {
                let url = Self.temporaryURL(extension: "m4a")
                let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
                self.recorder = recorder
                guard recorder.prepareToRecord(), recorder.record() else { throw MediaCaptureError.failedToStart }
                recordingStartedAt = Date()
                phase = .recording
                onStarted?()
            } else {
                video.start(url: Self.temporaryURL(extension: "mov"))
            }
        } catch { fail(error.localizedDescription) }
    }

    public func stop() {
        guard phase == .recording else { return }
        phase = .finishing
        if let recorder {
            let seconds = recorder.currentTime
            recorder.stop()
            self.recorder = nil
            finish(url: recorder.url, duration: seconds, type: .audio)
        } else { video.stop() }
    }

    public func cancel() {
        generation += 1
        if let recorder {
            recorder.stop()
            try? FileManager.default.removeItem(at: recorder.url)
        }
        recorder = nil
        video.cancel()
        if let result { try? FileManager.default.removeItem(at: result.url) }
        result = nil
        phase = .idle
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func receive(_ event: VideoRecordingWorker.Event) {
        switch event {
        case .started:
            guard phase == .preparing else { return }
            recordingStartedAt = Date()
            phase = .recording
            onStarted?()
        case let .finished(url, seconds):
            guard phase == .recording || phase == .finishing else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            phase = .finishing
            let token = generation
            Task { @MainActor [weak self] in
                // Load duration from the completed asset; callback timing is not media duration.
                let duration = (try? await MediaPlaybackService.videoDuration(url: url)) ?? seconds
                guard let self, generation == token, phase == .finishing else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                finish(url: url, duration: duration, type: .video)
            }
        case let .failed(message):
            guard phase != .idle else { return }
            fail(message)
        }
    }

    private func finish(url: URL, duration: TimeInterval, type: JournalMediaType) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard duration.isFinite, duration > 0 else {
            try? FileManager.default.removeItem(at: url)
            fail("The recording was too short to save. Record again.")
            return
        }
        result = CapturedMedia(url: url, duration: duration, type: type)
        phase = .finished
        onFinished?()
    }

    private func fail(_ message: String) {
        if let recorder {
            recorder.stop()
            try? FileManager.default.removeItem(at: recorder.url)
            self.recorder = nil
        }
        errorMessage = message
        phase = .failed
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private static func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }
}

/// Session configuration and start/stop all run on this serial queue. Delegate callbacks
/// enqueue before touching state; only the preview layer may reference the session on the main actor.
private final class VideoRecordingWorker: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    enum Event: Sendable { case started, finished(URL, TimeInterval), failed(String) }
    let session = AVCaptureSession()
    var onEvent: (@Sendable (Event) -> Void)?
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.trailmark.capture", qos: .userInitiated)
    private var configured = false
    private var cancelled = false

    func start(url: URL) {
        queue.async { [self] in
            cancelled = false
            do {
                if !configured { try configure() }
                if !session.isRunning { session.startRunning() }
                guard session.isRunning else { throw MediaCaptureError.failedToStart }
                output.startRecording(to: url, recordingDelegate: self)
            } catch {
                if session.isRunning { session.stopRunning() }
                try? FileManager.default.removeItem(at: url)
                onEvent?(.failed(error.localizedDescription))
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // A failed configuration is retryable; do not retain half-configured inputs.
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        guard let camera = AVCaptureDevice.default(for: .video), let microphone = AVCaptureDevice.default(for: .audio) else { throw MediaCaptureError.cameraUnavailable }
        for device in [camera, microphone] {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw MediaCaptureError.cameraUnavailable }
            session.addInput(input)
        }
        guard session.canAddOutput(output) else { throw MediaCaptureError.cameraUnavailable }
        session.addOutput(output)
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        output.maxRecordedDuration = CMTime(seconds: 120, preferredTimescale: 600)
        configured = true
    }

    func stop() { queue.async { [self] in if output.isRecording { output.stopRecording() } } }
    func cancel() {
        queue.async { [self] in
            cancelled = true
            if output.isRecording { output.stopRecording() }
            if session.isRunning { session.stopRunning() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        queue.async { [self] in
            if cancelled { self.output.stopRecording() }
            else { onEvent?(.started) }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Snapshot non-Sendable framework values before crossing the dispatch queue.
        let seconds = CMTimeGetSeconds(output.recordedDuration)
        let nsError = error as NSError?
        let succeeded = error == nil || (nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true)
        let message = error?.localizedDescription ?? "Video recording failed."
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            if cancelled || !succeeded {
                try? FileManager.default.removeItem(at: url)
                if !cancelled { onEvent?(.failed(message)) }
            } else { onEvent?(.finished(url, seconds)) }
        }
    }
}

private enum MediaCaptureError: LocalizedError {
    case failedToStart, cameraUnavailable
    var errorDescription: String? {
        switch self {
        case .failedToStart: "Recording could not start. Check permissions and try again."
        case .cameraUnavailable: "A usable camera and microphone are unavailable. Use a voice memo or import a video instead."
        }
    }
}
#endif
