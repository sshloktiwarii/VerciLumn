import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background accessory without Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Suppress automatic window tabbing warning on command-line SPM binaries
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Start non-invasive audio capture
        AudioBeatEngine.shared.startCapture()
        
        // Wire up Global System Hotkeys
        setupHotKeys()
        
        // Setup lockscreen/desktop overlays on startup
        setupOverlays()
        
        // Listen for screen layout changes (plugging/unplugging monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func handleScreenChange() {
        setupOverlays()
    }
    
    private func setupHotKeys() {
        let hotkeys = HotKeyManager.shared
        
        // ⌘ + ⇧ + L -> Toggle Full Stage Immersion
        hotkeys.onToggleStage = {
            let current = OverlayWindowManager.shared.currentMode
            let next: WindowDisplayMode = (current == .fullStage) ? .desktop : .fullStage
            OverlayWindowManager.shared.setDisplayMode(next)
            UserDefaults.standard.set(next.rawValue, forKey: "vercilumn_display_mode")
        }
        
        // ⌘ + ⌥ + → -> Cycle Animation Theme
        hotkeys.onCycleStyle = {
            let currentRaw = UserDefaults.standard.string(forKey: "vercilumn_lyric_style") ?? LyricStyle.verciReel.rawValue
            let all = LyricStyle.allCases
            let idx = all.firstIndex(where: { $0.rawValue == currentRaw }) ?? 0
            let nextStyle = all[(idx + 1) % all.count]
            UserDefaults.standard.set(nextStyle.rawValue, forKey: "vercilumn_lyric_style")
        }
        
        // ⌘ + [ / ⌘ + ] -> Adjust vocal sync timing offset
        hotkeys.onAdjustOffset = { delta in
            let cur = UserDefaults.standard.double(forKey: "vercilumn_timing_offset")
            let newOffset = min(max(cur + delta, -2.0), 2.0)
            UserDefaults.standard.set(newOffset, forKey: "vercilumn_timing_offset")
        }
    }
    
    private func setupOverlays() {
        let styleBinding = Binding(
            get: { LyricStyle(rawValue: UserDefaults.standard.string(forKey: "vercilumn_lyric_style") ?? "") ?? .verciReel },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "vercilumn_lyric_style") }
        )
        let bezelBinding = Binding(
            get: { UserDefaults.standard.bool(forKey: "vercilumn_bezel_enabled") },
            set: { UserDefaults.standard.set($0, forKey: "vercilumn_bezel_enabled") }
        )
        let sensitivityBinding = Binding(
            get: {
                let val = UserDefaults.standard.double(forKey: "vercilumn_glow_sensitivity")
                return val > 0 ? val : 1.0
            },
            set: { UserDefaults.standard.set($0, forKey: "vercilumn_glow_sensitivity") }
        )
        let backdropBinding = Binding(
            get: { BackdropMode(rawValue: UserDefaults.standard.string(forKey: "vercilumn_backdrop_mode") ?? "") ?? .particleCosmos },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "vercilumn_backdrop_mode") }
        )
        let offsetBinding = Binding(
            get: { UserDefaults.standard.double(forKey: "vercilumn_timing_offset") },
            set: { UserDefaults.standard.set($0, forKey: "vercilumn_timing_offset") }
        )
        let scaleBinding = Binding(
            get: {
                let s = UserDefaults.standard.double(forKey: "vercilumn_text_scale")
                return s > 0 ? s : 1.0
            },
            set: { UserDefaults.standard.set($0, forKey: "vercilumn_text_scale") }
        )
        
        let root = RootOverlayView(
            currentStyle: styleBinding,
            isBezelEnabled: bezelBinding,
            glowSensitivity: sensitivityBinding,
            backdropMode: backdropBinding,
            timingOffset: offsetBinding,
            textScale: scaleBinding
        )
        
        let initialMode = WindowDisplayMode(rawValue: UserDefaults.standard.string(forKey: "vercilumn_display_mode") ?? "") ?? .fullStage
        OverlayWindowManager.shared.setupOverlays(rootView: root, mode: initialMode)
    }
}

@main
struct VerciLumnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("vercilumn_lyric_style") private var storedStyle: String = LyricStyle.verciReel.rawValue
    @AppStorage("vercilumn_bezel_enabled") private var isBezelEnabled: Bool = true
    @AppStorage("vercilumn_glow_sensitivity") private var glowSensitivity: Double = 1.0
    @AppStorage("vercilumn_display_mode") private var storedDisplayMode: String = WindowDisplayMode.fullStage.rawValue
    @AppStorage("vercilumn_backdrop_mode") private var storedBackdropMode: String = BackdropMode.particleCosmos.rawValue
    @AppStorage("vercilumn_timing_offset") private var timingOffset: Double = 0.0
    @AppStorage("vercilumn_text_scale") private var textScale: Double = 1.0
    
    private var currentStyleBinding: Binding<LyricStyle> {
        Binding(
            get: { LyricStyle(rawValue: storedStyle) ?? .verciReel },
            set: { storedStyle = $0.rawValue }
        )
    }
    
    private var displayModeBinding: Binding<WindowDisplayMode> {
        Binding(
            get: { WindowDisplayMode(rawValue: storedDisplayMode) ?? .fullStage },
            set: { storedDisplayMode = $0.rawValue }
        )
    }
    
    private var backdropModeBinding: Binding<BackdropMode> {
        Binding(
            get: { BackdropMode(rawValue: storedBackdropMode) ?? .particleCosmos },
            set: { storedBackdropMode = $0.rawValue }
        )
    }
    
    var body: some Scene {
        MenuBarExtra("VerciLumn", systemImage: "waveform.badge.magnifyingglass") {
            MenuBarView(
                currentStyle: currentStyleBinding,
                isBezelEnabled: $isBezelEnabled,
                glowSensitivity: $glowSensitivity,
                displayMode: displayModeBinding,
                backdropMode: backdropModeBinding,
                timingOffset: $timingOffset,
                textScale: $textScale
            )
        }
        .menuBarExtraStyle(.window)
    }
}
