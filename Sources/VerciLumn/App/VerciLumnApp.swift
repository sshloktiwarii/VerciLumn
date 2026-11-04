import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background agent without Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Start non-invasive audio capture
        AudioBeatEngine.shared.startCapture()
        
        // Setup lockscreen overlays on startup
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
    
    private func setupOverlays() {
        let styleBinding = Binding(
            get: { LyricStyle(rawValue: UserDefaults.standard.string(forKey: "vercilumn_lyric_style") ?? "") ?? .standard },
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
        
        let root = RootOverlayView(
            currentStyle: styleBinding,
            isBezelEnabled: bezelBinding,
            glowSensitivity: sensitivityBinding
        )
        OverlayWindowManager.shared.setupOverlays(rootView: root)
    }
}

@main
struct VerciLumnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("vercilumn_lyric_style") private var storedStyle: String = LyricStyle.standard.rawValue
    @AppStorage("vercilumn_bezel_enabled") private var isBezelEnabled: Bool = true
    @AppStorage("vercilumn_glow_sensitivity") private var glowSensitivity: Double = 1.0
    
    private var currentStyleBinding: Binding<LyricStyle> {
        Binding(
            get: { LyricStyle(rawValue: storedStyle) ?? .standard },
            set: { storedStyle = $0.rawValue }
        )
    }
    
    var body: some Scene {
        MenuBarExtra("VerciLumn", systemImage: "waveform.badge.magnifyingglass") {
            MenuBarView(
                currentStyle: currentStyleBinding,
                isBezelEnabled: $isBezelEnabled,
                glowSensitivity: $glowSensitivity
            )
        }
        .menuBarExtraStyle(.window)
    }
}
