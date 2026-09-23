import SwiftUI
import TrailMarkCH10Core

/// Watch presentation tokens share the phone's identity on an OLED canvas.
enum WatchDesign {
    static let background = Color.black
    static let surface = TrailmarkTheme.surface(for: .dark)
    static let border = TrailmarkTheme.line(for: .dark)
    static let foreground = TrailmarkTheme.ink(for: .dark)
    static let muted = TrailmarkTheme.secondaryInk(for: .dark)
    static let accent = TrailmarkTheme.lime
    // Lighter clay and gold keep small labels legible against the watch's black canvas.
    static let coral = Color(red: 0.96, green: 0.56, blue: 0.43)
    static let gold = Color(red: 0.93, green: 0.75, blue: 0.40)
}

struct WatchActionStyle: ButtonStyle {
    var tint: Color = WatchDesign.accent
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(prominent ? Color.black : tint)
            .background(prominent ? tint : tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(prominent ? Color.clear : tint.opacity(0.22), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

struct WatchEyebrow: View {
    let title: String
    var color: Color = WatchDesign.muted

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(color)
    }
}

struct WatchMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color
    let accessibilityValue: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.65)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(WatchDesign.foreground)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WatchDesign.surface, in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }
}

struct WatchStateSymbol: View {
    let symbol: String
    var color: Color = WatchDesign.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(.title2, design: .rounded, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(color.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}
