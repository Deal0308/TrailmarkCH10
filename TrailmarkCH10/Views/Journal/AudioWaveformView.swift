import SwiftUI

/// Draws values supplied by the view model and forwards seek gestures.
struct AudioWaveformView: View {
    let samples: [Float]
    let progress: Double
    let level: Float
    let isPlaying: Bool
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !samples.isEmpty else { return }
                let slot = size.width / CGFloat(samples.count)
                for (index, sample) in samples.enumerated() {
                    let nearPlayhead = abs(Double(index) - progress * Double(samples.count)) < 4
                    let boost = isPlaying && nearPlayhead ? 1 + CGFloat(level) * 0.5 : 1
                    let height = max(2, min(1, CGFloat(sample) * boost) * size.height)
                    let rect = CGRect(x: CGFloat(index) * slot + slot * 0.2,
                                      y: (size.height - height) / 2, width: max(1, slot * 0.6), height: height)
                    let played = Double(index) / Double(samples.count) < progress
                    context.fill(Path(roundedRect: rect, cornerRadius: slot / 2),
                                 with: .color(played ? .blue : .secondary.opacity(0.35)))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard geometry.size.width > 0 else { return }
                onSeek(min(max(Double(value.location.x / geometry.size.width), 0), 1))
            })
        }
        .accessibilityElement()
        .accessibilityLabel("Audio waveform")
        .accessibilityValue("\(Int(progress * 100)) percent played")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSeek(min(progress + 0.05, 1))
            case .decrement: onSeek(max(progress - 0.05, 0))
            @unknown default: break
            }
        }
    }
}
