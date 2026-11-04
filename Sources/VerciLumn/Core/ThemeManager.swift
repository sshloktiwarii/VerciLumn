import SwiftUI
import Combine

public enum ColorThemePreset: String, CaseIterable, Identifiable {
    case albumReactive = "🎨 Album Reactive (Dynamic from Cover Art)"
    case blackAndWhite = "⚪ Black & White (Monochrome High Contrast)"
    case rainbow = "🌈 Rainbow Spectrum (Prismatic Multi-Hue)"
    case redFamily = "🔴 Red Family (Crimson, Ruby & Warm Scarlet)"
    case purpleSoft = "🟣 Purple Family Soft (Lavender, Lilac & Violet)"
    case blueFamily = "🔵 Blue Family (Ocean, Cobalt & Electric Cyan)"
    case greenFamily = "🟢 Green Family (Emerald, Mint & Neon Sage)"
    case brownFamily = "🟤 Brown Family (Caramel, Bronze & Warm Earth)"
    
    public var id: String { rawValue }
    
    public init?(rawValue: String) {
        if rawValue.contains("Album") {
            self = .albumReactive
        } else if rawValue.contains("Black") || rawValue.contains("Monochrome") || rawValue.contains("minimalist") {
            self = .blackAndWhite
        } else if rawValue.contains("Rainbow") {
            self = .rainbow
        } else if rawValue.contains("Red") {
            self = .redFamily
        } else if rawValue.contains("Purple") || rawValue.contains("tokyoMidnight") {
            self = .purpleSoft
        } else if rawValue.contains("Blue") || rawValue.contains("cyberpunk") {
            self = .blueFamily
        } else if rawValue.contains("Green") || rawValue.contains("emeraldMatrix") {
            self = .greenFamily
        } else if rawValue.contains("Brown") {
            self = .brownFamily
        } else {
            for val in ColorThemePreset.allCases {
                if val.rawValue == rawValue {
                    self = val
                    return
                }
            }
            return nil
        }
    }
    
    public var palette: ColorPalette {
        switch self {
        case .albumReactive:
            return ColorPaletteManager.shared.currentPalette
            
        case .blackAndWhite:
            return ColorPalette(
                background: Color(white: 0.04),
                primaryText: Color.white,
                highlightAccent: Color.white,
                secondaryGlow: Color(white: 0.82)
            )
            
        case .rainbow:
            return ColorPalette(
                background: Color(red: 0.04, green: 0.03, blue: 0.06),
                primaryText: Color.white,
                highlightAccent: Color(red: 1.0, green: 0.28, blue: 0.75),
                secondaryGlow: Color(red: 0.15, green: 0.85, blue: 1.0),
                isRainbow: true
            )
            
        case .redFamily:
            return ColorPalette(
                background: Color(red: 0.06, green: 0.02, blue: 0.02),
                primaryText: Color.white,
                highlightAccent: Color(red: 1.0, green: 0.2, blue: 0.28), // Bright Crimson
                secondaryGlow: Color(red: 0.85, green: 0.35, blue: 0.15) // Deep Ruby Ember
            )
            
        case .purpleSoft:
            return ColorPalette(
                background: Color(red: 0.05, green: 0.03, blue: 0.07),
                primaryText: Color.white,
                highlightAccent: Color(red: 0.82, green: 0.65, blue: 1.0), // Soft Pastel Lavender
                secondaryGlow: Color(red: 0.62, green: 0.45, blue: 0.95) // Soft Lilac Violet
            )
            
        case .blueFamily:
            return ColorPalette(
                background: Color(red: 0.02, green: 0.04, blue: 0.07),
                primaryText: Color.white,
                highlightAccent: Color(red: 0.2, green: 0.78, blue: 1.0), // Electric Cyan
                secondaryGlow: Color(red: 0.12, green: 0.45, blue: 0.95) // Deep Ocean Cobalt
            )
            
        case .greenFamily:
            return ColorPalette(
                background: Color(red: 0.02, green: 0.05, blue: 0.03),
                primaryText: Color.white,
                highlightAccent: Color(red: 0.2, green: 0.96, blue: 0.55), // Vibrant Mint Emerald
                secondaryGlow: Color(red: 0.1, green: 0.75, blue: 0.4) // Neon Sage Flora
            )
            
        case .brownFamily:
            return ColorPalette(
                background: Color(red: 0.06, green: 0.04, blue: 0.03),
                primaryText: Color.white,
                highlightAccent: Color(red: 0.92, green: 0.68, blue: 0.42), // Warm Caramel Bronze
                secondaryGlow: Color(red: 0.65, green: 0.45, blue: 0.28) // Rich Roasted Espresso
            )
        }
    }
}

public enum TypographyStyle: String, CaseIterable, Identifiable {
    case rounded = "SF Pro Rounded"
    case serif = "New York Editorial Serif"
    case monospaced = "Industrial Monospace"
    case standard = "SF Pro Display"
    
    public var id: String { rawValue }
    
    public var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .standard: return .default
        }
    }
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: ColorThemePreset = .albumReactive
    @Published public var currentTypography: TypographyStyle = .rounded
    
    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "vercilumn_theme_preset"),
           let theme = ColorThemePreset(rawValue: savedTheme) {
            self.currentTheme = theme
        }
        if let savedFont = UserDefaults.standard.string(forKey: "vercilumn_typography_style"),
           let font = TypographyStyle(rawValue: savedFont) {
            self.currentTypography = font
        }
    }
    
    public func setTheme(_ theme: ColorThemePreset) {
        self.currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "vercilumn_theme_preset")
    }
    
    public func setTypography(_ style: TypographyStyle) {
        self.currentTypography = style
        UserDefaults.standard.set(style.rawValue, forKey: "vercilumn_typography_style")
    }
    
    public var activePalette: ColorPalette {
        if currentTheme == .albumReactive {
            return ColorPaletteManager.shared.currentPalette
        }
        return currentTheme.palette
    }
}
