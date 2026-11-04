import SwiftUI
import Combine

public enum ColorThemePreset: String, CaseIterable, Identifiable {
    case albumReactive = "Album Reactive (Dynamic)"
    case cyberpunk = "Cyberpunk 2077 (Neon Yellow & Cyan)"
    case tokyoMidnight = "Tokyo Midnight (Hot Pink & Violet)"
    case minimalist = "Monochrome Minimalist (White & Silver)"
    case emeraldMatrix = "Emerald Matrix (Phosphor Green)"
    
    public var id: String { rawValue }
    
    public var palette: ColorPalette {
        switch self {
        case .albumReactive:
            return ColorPaletteManager.shared.currentPalette
        case .cyberpunk:
            return ColorPalette(
                background: Color(red: 0.05, green: 0.05, blue: 0.07),
                primaryText: .white,
                highlightAccent: Color(red: 0.99, green: 0.93, blue: 0.04), // #FCEE0A
                secondaryGlow: Color(red: 0.0, green: 0.94, blue: 1.0)     // #00F0FF
            )
        case .tokyoMidnight:
            return ColorPalette(
                background: Color(red: 0.04, green: 0.02, blue: 0.08),
                primaryText: .white,
                highlightAccent: Color(red: 1.0, green: 0.0, blue: 0.5),    // #FF007F
                secondaryGlow: Color(red: 0.62, green: 0.0, blue: 1.0)     // #9D00FF
            )
        case .minimalist:
            return ColorPalette(
                background: Color(white: 0.05),
                primaryText: .white,
                highlightAccent: Color.white,
                secondaryGlow: Color(white: 0.75)
            )
        case .emeraldMatrix:
            return ColorPalette(
                background: Color(red: 0.02, green: 0.06, blue: 0.03),
                primaryText: .white,
                highlightAccent: Color(red: 0.0, green: 1.0, blue: 0.4),
                secondaryGlow: Color(red: 0.0, green: 0.8, blue: 0.8)
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
