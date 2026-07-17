//
//  Theme.swift
//  Cadence
//

import SwiftUI
import UIKit

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

/// Central design tokens for Cadence's adaptive, amber-accented aesthetic.
enum Theme {
    static let appearancePreference: AppAppearancePreference = .system

    static var preferredColorScheme: ColorScheme? {
        switch appearancePreference {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static let background = adaptive(light: .systemBackground, dark: uiColor(hex: 0x0B0B0F))
    static let surface = adaptive(light: .secondarySystemBackground, dark: uiColor(hex: 0x16161C))
    static let surfaceElevated = adaptive(light: .tertiarySystemBackground, dark: uiColor(hex: 0x20202A))
    static let stroke = adaptive(light: .separator, dark: uiColor(hex: 0x2A2A34))
    static let strokeSoft = adaptive(
        light: UIColor.separator.withAlphaComponent(0.42),
        dark: UIColor.white.withAlphaComponent(0.06)
    )

    static let accent = Color(hex: 0xF5B841)
    static let accentSoft = Color(hex: 0xF5B841).opacity(0.16)
    static let coolAccent = Color(hex: 0x8AD7C1)
    static let onAccent = Color(hex: 0x111116)
    static let shadow = adaptive(
        light: UIColor.black.withAlphaComponent(0.10),
        dark: UIColor.black.withAlphaComponent(0.24)
    )
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xF7C65B), Color(hex: 0xE9A227)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let surfaceGradient = LinearGradient(
        colors: [
            adaptive(light: .secondarySystemBackground, dark: uiColor(hex: 0x1E1E27)),
            adaptive(light: .systemBackground, dark: uiColor(hex: 0x111116))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    /// Warm radial glow used behind headers and empty states.
    static let glow = RadialGradient(
        colors: [Color(hex: 0xF5B841).opacity(0.10), Color.clear],
        center: .top,
        startRadius: 0,
        endRadius: 420
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func uiColor(hex: UInt, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
