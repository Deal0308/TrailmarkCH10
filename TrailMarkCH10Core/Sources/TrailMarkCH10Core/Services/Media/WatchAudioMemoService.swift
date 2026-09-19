#if os(watchOS)
import AVFoundation
import Foundation

/// Owns watch microphone access and audio recording. Framework types remain
/// inside TrailMarkCH10Core and never reach a SwiftUI view.
@MainActor
final class WatchAudioMemoService {
    private var recorder: AVAudioRecorder?

    func start() async throws -> Date {
        cancel()

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw WatchAudioMemoError.microphoneDenied }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.prepareToRecord(), recorder.record() else {
                throw WatchAudioMemoError.failedToStart
            }
            self.recorder = recorder
            return Date()
        } catch {
            try? FileManager.default.removeItem(at: url)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop() throws -> CapturedMedia {
        guard let recorder else { throw WatchAudioMemoError.notRecording }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Read duration from the finalized file so metadata does not depend on
        // timer cadence or when the Stop button callback happened to run.
        do {
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            guard duration.isFinite, duration >= 0.5 else {
                throw WatchAudioMemoError.tooShort
            }
            return CapturedMedia(url: url, duration: duration, type: .audio)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        try? FileManager.default.removeItem(at: recorder.url)
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private enum WatchAudioMemoError: LocalizedError {
    case microphoneDenied
    case failedToStart
    case notRecording
    case tooShort

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Allow microphone access in Settings to record a voice memo."
        case .failedToStart:
            "The watch could not start recording. Check microphone access and try again."
        case .notRecording:
            "No voice memo is currently recording."
        case .tooShort:
            "That memo was too short to save. Record a little longer and try again."
        }
    }
}
#endif
