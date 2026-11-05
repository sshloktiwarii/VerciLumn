import SwiftUI
import Combine

public enum BezelSourceMode: String, CaseIterable, Identifiable {
    case audioReactive = "Audio Reactive (FFT)"
    case screenSampling = "Screen Ambilight (CGDisplayStream)"
    
    public var id: String { rawValue }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // Keys
    private enum Keys {
        static let lyricStyle = "vercilumn_lyric_style"
        static let bezelEnabled = "vercilumn_bezel_enabled"
        static let bezelSourceMode = "vercilumn_bezel_source_mode"
        static let glowSensitivity = "vercilumn_glow_sensitivity"
        static let displayMode = "vercilumn_display_mode"
        static let backdropMode = "vercilumn_backdrop_mode"
        static let timingOffset = "vercilumn_timing_offset"
        static let textScale = "vercilumn_text_scale"
        static let notchHUDEnabled = "vercilumn_notch_hud_enabled"
        static let interactiveSeekEnabled = "vercilumn_interactive_seek_enabled"
        static let fisheyeShaderEnabled = "vercilumn_fisheye_shader_enabled"
        static let lowPowerModeEnabled = "vercilumn_low_power_mode_enabled"
        static let translationEnabled = "vercilumn_translation_enabled"
        static let translationLanguage = "vercilumn_translation_language"
        static let immersiveModeEnabled = "vercilumn_immersive_mode_enabled"
    }
    
    // Published Properties
    @Published public var lyricStyle: LyricStyle {
        didSet { UserDefaults.standard.set(lyricStyle.rawValue, forKey: Keys.lyricStyle) }
    }
    
    @Published public var isBezelEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBezelEnabled, forKey: Keys.bezelEnabled)
            if isBezelEnabled && bezelSourceMode == .screenSampling {
                ScreenSampler.shared.start()
            } else {
                ScreenSampler.shared.stop()
            }
        }
    }
    
    @Published public var bezelSourceMode: BezelSourceMode {
        didSet {
            UserDefaults.standard.set(bezelSourceMode.rawValue, forKey: Keys.bezelSourceMode)
            if isBezelEnabled && bezelSourceMode == .screenSampling {
                ScreenSampler.shared.start()
            } else {
                ScreenSampler.shared.stop()
            }
        }
    }
    
    @Published public var glowSensitivity: Double {
        didSet { UserDefaults.standard.set(glowSensitivity, forKey: Keys.glowSensitivity) }
    }
    
    @Published public var displayMode: WindowDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: Keys.displayMode)
            OverlayWindowManager.shared.setDisplayMode(displayMode)
        }
    }
    
    @Published public var backdropMode: BackdropMode {
        didSet { UserDefaults.standard.set(backdropMode.rawValue, forKey: Keys.backdropMode) }
    }
    
    @Published public var timingOffset: Double {
        didSet { UserDefaults.standard.set(timingOffset, forKey: Keys.timingOffset) }
    }
    
    @Published public var textScale: Double {
        didSet { UserDefaults.standard.set(textScale, forKey: Keys.textScale) }
    }
    
    @Published public var isNotchHUDEnabled: Bool {
        didSet { UserDefaults.standard.set(isNotchHUDEnabled, forKey: Keys.notchHUDEnabled) }
    }
    
    @Published public var isInteractiveSeekEnabled: Bool {
        didSet { UserDefaults.standard.set(isInteractiveSeekEnabled, forKey: Keys.interactiveSeekEnabled) }
    }
    
    @Published public var isFisheyeShaderEnabled: Bool {
        didSet { UserDefaults.standard.set(isFisheyeShaderEnabled, forKey: Keys.fisheyeShaderEnabled) }
    }
    
    @Published public var isLowPowerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isLowPowerModeEnabled, forKey: Keys.lowPowerModeEnabled) }
    }
    
    @Published public var isTranslationEnabled: Bool {
        didSet { UserDefaults.standard.set(isTranslationEnabled, forKey: Keys.translationEnabled) }
    }
    
    @Published public var translationLanguage: String {
        didSet { UserDefaults.standard.set(translationLanguage, forKey: Keys.translationLanguage) }
    }
    
    @Published public var isImmersiveModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isImmersiveModeEnabled, forKey: Keys.immersiveModeEnabled)
            OverlayWindowManager.shared.setImmersiveMode(isImmersiveModeEnabled)
        }
    }
    
    // Tactile Timing HUD Feedback
    @Published public var isTimingHUDVisible: Bool = false
    @Published public var timingHUDMessage: String = ""
    private var timingHUDDismissWorkItem: DispatchWorkItem?
    
    public func nudgeTimingOffset(by delta: Double) {
        guard !delta.isNaN && !delta.isInfinite else { return }
        let rounded = (round((timingOffset + delta) * 100.0) / 100.0)
        let clamped = min(max(rounded, -10.0), 10.0)
        self.timingOffset = clamped
        
        let deltaMs = Int(round(delta * 1000.0))
        let totalMs = Int(round(clamped * 1000.0))
        let deltaPrefix = deltaMs >= 0 ? "+\(deltaMs)" : "\(deltaMs)"
        let totalPrefix = totalMs >= 0 ? "+\(totalMs)" : "\(totalMs)"
        
        triggerTimingHUD(message: "Sync Offset: \(deltaPrefix)ms (\(totalPrefix)ms total)")
    }
    
    public func resetTimingOffset() {
        self.timingOffset = 0.0
        triggerTimingHUD(message: "Sync Offset: Reset to 0ms")
    }
    
    public func triggerTimingHUD(message: String) {
        timingHUDDismissWorkItem?.cancel()
        self.timingHUDMessage = message
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            self.isTimingHUDVisible = true
        }
        
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) {
                self?.isTimingHUDVisible = false
            }
        }
        self.timingHUDDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: item)
    }
    
    public var targetFpsInterval: Double {
        return isLowPowerModeEnabled ? (1.0 / 30.0) : (1.0 / 45.0)
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        let savedStyleRaw = defaults.string(forKey: Keys.lyricStyle) ?? ""
        self.lyricStyle = LyricStyle(rawValue: savedStyleRaw) ?? .verciReel
        
        self.isBezelEnabled = defaults.object(forKey: Keys.bezelEnabled) != nil ? defaults.bool(forKey: Keys.bezelEnabled) : true
        
        let savedBezelSourceRaw = defaults.string(forKey: Keys.bezelSourceMode) ?? ""
        self.bezelSourceMode = BezelSourceMode(rawValue: savedBezelSourceRaw) ?? .audioReactive
        
        let sensitivity = defaults.double(forKey: Keys.glowSensitivity)
        self.glowSensitivity = sensitivity > 0 ? sensitivity : 1.0
        
        let savedModeRaw = defaults.string(forKey: Keys.displayMode) ?? ""
        self.displayMode = WindowDisplayMode(rawValue: savedModeRaw) ?? .fullStage
        
        let savedBackdropRaw = defaults.string(forKey: Keys.backdropMode) ?? ""
        self.backdropMode = BackdropMode(rawValue: savedBackdropRaw) ?? .transparent
        
        self.timingOffset = defaults.double(forKey: Keys.timingOffset)
        
        let scale = defaults.double(forKey: Keys.textScale)
        self.textScale = scale > 0 ? scale : 1.0
        
        self.isNotchHUDEnabled = defaults.object(forKey: Keys.notchHUDEnabled) != nil ? defaults.bool(forKey: Keys.notchHUDEnabled) : true
        
        self.isInteractiveSeekEnabled = defaults.object(forKey: Keys.interactiveSeekEnabled) != nil ? defaults.bool(forKey: Keys.interactiveSeekEnabled) : true
        
        // Disabled by default to protect laptop thermals unless explicitly requested
        self.isFisheyeShaderEnabled = defaults.bool(forKey: Keys.fisheyeShaderEnabled)
        
        self.isLowPowerModeEnabled = defaults.bool(forKey: Keys.lowPowerModeEnabled)
        
        self.isTranslationEnabled = defaults.object(forKey: Keys.translationEnabled) != nil ? defaults.bool(forKey: Keys.translationEnabled) : true
        self.translationLanguage = defaults.string(forKey: Keys.translationLanguage) ?? "en"
        
        self.isImmersiveModeEnabled = defaults.bool(forKey: Keys.immersiveModeEnabled)
        
        if self.isBezelEnabled && self.bezelSourceMode == .screenSampling {
            ScreenSampler.shared.start()
        }
    }
}
