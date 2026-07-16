//
//  Theme.swift
//  Cadence
//

import SwiftUI

/// Central design tokens for Cadence's dark, amber-accented aesthetic.
enum Theme {
    static let background = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x16161C)
    static let surfaceElevated = Color(hex: 0x20202A)
    static let stroke = Color(hex: 0x2A2A34)

    static let accent = Color(hex: 0xF5B841)
    static let accentSoft = Color(hex: 0xF5B841).opacity(0.16)
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xF7C65B), Color(hex: 0xE9A227)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(hex: 0x9A9AA6)
    static let textTertiary = Color(hex: 0x63636E)

    /// Warm radial glow used behind headers and empty states.
    static let glow = RadialGradient(
        colors: [Color(hex: 0xF5B841).opacity(0.10), .clear],
        center: .top,
        startRadius: 0,
        endRadius: 420
    )
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
