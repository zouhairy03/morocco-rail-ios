//
//  Theme.swift
//  Brand colours, typography and reusable styling for ONCF Voyages.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
    /// Adaptive colour: light value in light mode, dark value in dark mode.
    init(light: UInt, dark: UInt) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255,
                  green: CGFloat((rgb >> 8) & 0xff) / 255,
                  blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }
}

enum Brand {
    // Brand accents — fixed in both modes
    static let orange  = Color(hex: 0xF2660A)
    static let orange2 = Color(hex: 0xFF7A1A)
    static let orange3 = Color(hex: 0xE0480A)
    static let gold    = Color(hex: 0xE8B04B)
    static let clay    = Color(light: 0xC75B39, dark: 0xE3835F)
    // Always-dark accent surfaces (loyalty card, header, pay bar)
    static let ink     = Color(hex: 0x0B1020)
    static let ink2    = Color(hex: 0x11162A)
    // Adaptive neutrals
    static let sand    = Color(light: 0xF7F1E7, dark: 0x0E1117)   // app background
    static let sand2   = Color(light: 0xEFE6D6, dark: 0x141A24)
    static let cream   = Color(light: 0xFFFDF8, dark: 0x1A2030)   // cards
    static let textSoft = Color(light: 0x5A6178, dark: 0x9AA1B4)
    static let label   = Color(light: 0x0B1020, dark: 0xF2F5FB)   // primary text
    static let field   = Color(light: 0xFFFFFF, dark: 0x232A3B)   // input/field backgrounds

    static let warm = LinearGradient(colors: [orange3, orange2, gold],
                                     startPoint: .leading, endPoint: .trailing)
    static let inkGrad = LinearGradient(colors: [ink2, ink],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let logoGrad = LinearGradient(colors: [orange2, orange3],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Reusable styling

/// Primary pill button used across the app.
struct PrimaryButtonStyle: ButtonStyle {
    var block = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: block ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, block ? 0 : 26)
            .background(Brand.warm, in: Capsule())
            .shadow(color: Brand.orange.opacity(0.45), radius: 14, y: 8)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Soft card container.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(Brand.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06)))
            .shadow(color: Brand.ink.opacity(0.08), radius: 18, y: 10)
    }
}

struct Eyebrow: View {
    let text: String
    var light = false
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Brand.orange).frame(width: 7, height: 7)
            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
        }
        .foregroundStyle(light ? Color.white.opacity(0.8) : Brand.clay)
    }
}

/// The ONCF logo mark (orange rounded square + train glyph).
struct LogoMark: View {
    var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Brand.logoGrad)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "tram.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: Brand.orange.opacity(0.4), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}

extension View {
    func sectionTitle() -> some View {
        self.font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(Brand.label)
    }
}
