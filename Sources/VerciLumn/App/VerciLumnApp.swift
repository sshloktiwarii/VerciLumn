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
        HotKeyManager.shared.startHotkeyMonitors()
        
        // Setup lockscreen/desktop overlays & Dynamic Notch Panel on startup
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
        OverlayWindowManager.shared.updateScreenLayout()
    }
    
    private func setupOverlays() {
        let root = RootOverlayView()
        let initialMode = AppSettings.shared.displayMode
        OverlayWindowManager.shared.setupOverlays(rootView: root, mode: initialMode)
    }
}

@main
struct VerciLumnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("VerciLumn", systemImage: "waveform.badge.magnifyingglass") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
