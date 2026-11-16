import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A color that switches between a dark-mode and light-mode value.
    static func adaptive(dark: UInt32, light: UInt32, darkOpacity: Double = 1, lightOpacity: Double = 1) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light
                ? UIColor(hex: light, alpha: lightOpacity)
                : UIColor(hex: dark, alpha: darkOpacity)
        })
        #else
        return Color(hex: dark, opacity: darkOpacity)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: CGFloat(alpha))
    }
}
#endif

/// The PrayToScroll palette. Dark-first, with a warm light mode.
enum Palette {
    static let midnight = Color(hex: 0x0E1726)
    static let midnightDeep = Color(hex: 0x09101C)
    static let ink = Color(hex: 0x16233A)
    static let inkRaised = Color(hex: 0x1D2D49)
    static let gold = Color(hex: 0xE9B949)
    static let warmGold = Color(hex: 0xF5D58A)
    static let deepGold = Color(hex: 0xB8862B)
    static let cream = Color(hex: 0xFBF6EC)
    static let parchment = Color(hex: 0xF3E9D6)
    static let sage = Color(hex: 0xA8C3A0)
    static let rose = Color(hex: 0xE7A6A1)
    static let ember = Color(hex: 0xF08A4B)

    static let goldGradient = LinearGradient(colors: [warmGold, gold, deepGold], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldButton = LinearGradient(colors: [Color(hex: 0xF7DE9C), gold], startPoint: .top, endPoint: .bottom)
    static let flameGradient = LinearGradient(colors: [warmGold, gold, ember, rose], startPoint: .top, endPoint: .bottom)
}

/// Semantic colors used across the app and the widget.
enum Theme {
    static let background = Color.adaptive(dark: 0x0E1726, light: 0xFBF6EC)
    static let backgroundDeep = Color.adaptive(dark: 0x09101C, light: 0xF3E9D6)
    static let surface = Color.adaptive(dark: 0x16233A, light: 0xFFFFFF, darkOpacity: 0.78, lightOpacity: 0.92)
    static let surfaceSolid = Color.adaptive(dark: 0x16233A, light: 0xFFFFFF)
    static let surfaceRaised = Color.adaptive(dark: 0x1D2D49, light: 0xFFFDF8)
    static let textPrimary = Color.adaptive(dark: 0xFBF6EC, light: 0x0E1726)
    static let textSecondary = Color.adaptive(dark: 0xFBF6EC, light: 0x0E1726, darkOpacity: 0.70, lightOpacity: 0.66)
    static let textTertiary = Color.adaptive(dark: 0xFBF6EC, light: 0x0E1726, darkOpacity: 0.48, lightOpacity: 0.45)
    static let stroke = Color.adaptive(dark: 0xFFFFFF, light: 0x0E1726, darkOpacity: 0.09, lightOpacity: 0.08)
    static let strokeStrong = Color.adaptive(dark: 0xFFFFFF, light: 0x0E1726, darkOpacity: 0.16, lightOpacity: 0.14)
    /// Gold for text and icons: bright on midnight, deepened on cream for contrast.
    static let goldText = Color.adaptive(dark: 0xF5D58A, light: 0x9A6A12)
    static let goldIcon = Color.adaptive(dark: 0xE9B949, light: 0xB8862B)
    static let sageText = Color.adaptive(dark: 0xA8C3A0, light: 0x4F7A47)
    static let roseText = Color.adaptive(dark: 0xE7A6A1, light: 0xB2544D)
    static let shadow = Color.adaptive(dark: 0x000000, light: 0x5B4A2A, darkOpacity: 0.35, lightOpacity: 0.12)
}
