#if os(iOS) || os(watchOS)
import SwiftUI

/// Shared visual language. These are presentation tokens, independent of app data.
public enum TrailmarkTheme {
    public static let forest = Color(red: 0.09, green: 0.24, blue: 0.20)
    public static let lime = Color(red: 0.85, green: 0.95, blue: 0.55)
    public static let clay = Color(red: 0.68, green: 0.28, blue: 0.19)
    public static let sky = Color(red: 0.16, green: 0.43, blue: 0.54)
    public static let lavender = Color(red: 0.46, green: 0.38, blue: 0.66)
    public static let gold = Color(red: 0.62, green: 0.40, blue: 0.12)
    public static let cream = Color(red: 0.96, green: 0.96, blue: 0.92)

    public static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.04, green: 0.08, blue: 0.065) : cream
    }
    public static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.085, green: 0.15, blue: 0.12) : Color(red: 1, green: 1, blue: 0.985)
    }
    public static func ink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cream : Color(red: 0.075, green: 0.16, blue: 0.13)
    }
    public static func secondaryInk(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.69, green: 0.76, blue: 0.71) : Color(red: 0.34, green: 0.41, blue: 0.37)
    }
    public static func line(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.20, green: 0.29, blue: 0.24) : Color(red: 0.85, green: 0.88, blue: 0.82)
    }
    public static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? lime : forest
    }
}

/// Decorative topographic lines; these never represent a recorded route or measurement.
public struct TrailmarkContours: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<13 {
            let step = CGFloat(index) * 0.065
            path.move(to: CGPoint(x: rect.width * (0.38 + step), y: -rect.height * 0.15))
            path.addCurve(
                to: CGPoint(x: rect.width * (0.78 + step), y: rect.height * 1.2),
                control1: CGPoint(x: rect.width * (-0.03 + step), y: rect.height * 0.45),
                control2: CGPoint(x: rect.width * (1.32 + step), y: rect.height * 0.30)
            )
        }
        return path
    }
}

public struct TrailmarkHero<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .foregroundStyle(.white)
            .background {
                ZStack {
                    LinearGradient(colors: [TrailmarkTheme.forest, Color(red: 0.06, green: 0.17, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    TrailmarkContours()
                        .stroke(TrailmarkTheme.lime.opacity(0.11), lineWidth: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

public struct TrailmarkSectionHeader: View {
    private let eyebrow: String
    private let title: String
    private let subtitle: String?
    @Environment(\.colorScheme) private var scheme
    public init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(TrailmarkTheme.ink(for: scheme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct TrailmarkBadge: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color?
    @Environment(\.colorScheme) private var scheme
    public init(_ title: String, systemImage: String? = nil, tint: Color? = nil) {
        self.title = title; self.systemImage = systemImage; self.tint = tint
    }
    public var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(scheme == .dark ? TrailmarkTheme.cream : (tint ?? TrailmarkTheme.accent(for: scheme)))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((tint ?? TrailmarkTheme.accent(for: scheme)).opacity(0.10), in: Capsule())
    }
}

public struct TrailmarkMetricTile: View {
    private let title: String
    private let value: String
    private let unit: String?
    private let systemImage: String
    private let tint: Color
    @Environment(\.colorScheme) private var scheme
    public init(title: String, value: String, unit: String? = nil, systemImage: String, tint: Color) {
        self.title = title; self.value = value; self.unit = unit; self.systemImage = systemImage; self.tint = tint
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(scheme == .dark ? TrailmarkTheme.cream : tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(scheme == .dark ? 0.28 : 0.10), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let unit, !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailmarkCard()
        .accessibilityElement(children: .combine)
    }
}

public struct TrailmarkNotice: View {
    private let title: String
    private let message: String
    private let systemImage: String
    private let tint: Color?
    @Environment(\.colorScheme) private var scheme
    public init(title: String, message: String, systemImage: String = "info.circle", tint: Color? = nil) {
        self.title = title; self.message = message; self.systemImage = systemImage; self.tint = tint
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scheme == .dark ? TrailmarkTheme.cream : (tint ?? TrailmarkTheme.forest))
            Text(message)
                .font(.footnote)
                .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background((tint ?? TrailmarkTheme.accent(for: scheme)).opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

public struct TrailmarkEmptyState: View {
    private let title: String
    private let message: String
    private let systemImage: String
    @Environment(\.colorScheme) private var scheme
    public init(title: String, message: String, systemImage: String) {
        self.title = title; self.message = message; self.systemImage = systemImage
    }
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(TrailmarkTheme.accent(for: scheme))
                .frame(width: 76, height: 76)
                .background(TrailmarkTheme.accent(for: scheme).opacity(0.07), in: Circle())
                .overlay { Circle().strokeBorder(TrailmarkTheme.line(for: scheme), lineWidth: 1) }
                .accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif, weight: .medium))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TrailmarkTheme.secondaryInk(for: scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
    }
}

public struct TrailmarkPrimaryButtonStyle: ButtonStyle {
    private let tint: Color?
    private let foreground: Color?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    public init(tint: Color? = nil, foreground: Color? = nil) {
        self.tint = tint; self.foreground = foreground
    }
    public func makeBody(configuration: Configuration) -> some View {
        let isDestructive = configuration.role == .destructive
        let fill = tint ?? (isDestructive ? TrailmarkTheme.clay : TrailmarkTheme.accent(for: scheme))
        let text = foreground ?? (tint == nil && scheme == .dark && !isDestructive ? TrailmarkTheme.forest : .white)
        return configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .foregroundStyle(text)
            .tint(text)
            .background(fill.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

public struct TrailmarkSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        let isDestructive = configuration.role == .destructive
        let accent = isDestructive
            ? (scheme == .dark ? Color(red: 0.96, green: 0.65, blue: 0.54) : TrailmarkTheme.clay)
            : TrailmarkTheme.accent(for: scheme)
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 14)
            .foregroundStyle(accent)
            .tint(accent)
            .background(accent.opacity(configuration.isPressed ? 0.15 : 0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(TrailmarkTheme.line(for: scheme), lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct TrailmarkCardModifier: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(TrailmarkTheme.surface(for: scheme), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(TrailmarkTheme.line(for: scheme).opacity(0.65), lineWidth: 0.75) }
    }
}

private struct TrailmarkScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .foregroundStyle(TrailmarkTheme.ink(for: scheme))
            .background(TrailmarkTheme.background(for: scheme).ignoresSafeArea())
            .tint(TrailmarkTheme.accent(for: scheme))
    }
}

public extension View {
    func trailmarkCard(padding: CGFloat = 20) -> some View {
        modifier(TrailmarkCardModifier(padding: padding))
    }
    func trailmarkScreen() -> some View {
        modifier(TrailmarkScreenModifier())
    }
}
#endif
