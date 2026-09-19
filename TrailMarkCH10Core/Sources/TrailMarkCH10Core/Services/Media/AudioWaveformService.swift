#if os(iOS)
import AVFoundation
import Foundation

/// Decodes real audio samples off the main actor using bounded buffers.
public enum AudioWaveformService {
    public static func amplitudes(url: URL, barCount: Int = 96) async -> [Float] {
        guard (1...512).contains(barCount) else { return [] }
        let worker = Task.detached(priority: .utility) {
            (try? decode(url: url, barCount: barCount)) ?? []
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func decode(url: URL, barCount: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { return [] }
        var sums = [Double](repeating: 0, count: barCount)
        var counts = [Int](repeating: 0, count: barCount)
        while file.framePosition < file.length {
            try Task.checkCancellation()
            let start = file.framePosition
            try file.read(into: buffer, frameCount: AVAudioFrameCount(min(4096, file.length - start)))
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { return [] }
            for frame in 0..<Int(buffer.frameLength) {
                let bucket = min(barCount - 1, Int(Double(start + Int64(frame)) / Double(file.length) * Double(barCount)))
                for channel in 0..<Int(file.processingFormat.channelCount) {
                    let sample = Double(channels[channel][frame])
                    if sample.isFinite { sums[bucket] += sample * sample; counts[bucket] += 1 }
                }
            }
        }
        let rms = sums.indices.map { counts[$0] > 0 ? sqrt(sums[$0] / Double(counts[$0])) : 0 }
        guard let peak = rms.max(), peak > 0 else { return [Float](repeating: 0, count: barCount) }
        return rms.map { Float(min(pow($0 / peak, 0.7), 1)) }
    }
}
#endif
