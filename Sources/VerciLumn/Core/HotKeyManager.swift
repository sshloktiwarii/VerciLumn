import AppKit
import Combine
import ApplicationServices

public final class HotKeyManager: ObservableObject {
    public static let shared = HotKeyManager()
    
    @Published public var isIdleScreensaverEnabled: Bool = true
    @Published public var idleThresholdSeconds: Double = 60.0
    @Published public private(set) var isAccessibilityGranted: Bool = false
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var idleCheckTimer: AnyCancellable?
    private var isCurrentlyInAutoScreensaver: Bool = false
    private var previousDisplayMode: WindowDisplayMode = .fullStage
    
    public var onToggleStage: (() -> Void)?
    public var onCycleStyle: (() -> Void)?
    public var onAdjustOffset: ((Double) -> Void)?
    
    private init() {
        checkAccessibilityPermissions()
        startHotkeyMonitors()
        startIdleTimer()
    }
    
    deinit {
        stopHotkeyMonitors()
        idleCheckTimer?.cancel()
    }
    
    @discardableResult
    public func checkAccessibilityPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async { [weak self] in
            self?.isAccessibilityGranted = trusted
        }
        return trusted
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func startHotkeyMonitors() {
        // Global Key Monitor (when other applications have focus)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, isLocal: false)
        }
        
        // Local Key Monitor (when VerciLumn has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event, isLocal: true) == true {
                return nil // consume event
            }
            return event
        }
    }
    
    public func stopHotkeyMonitors() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent, isLocal: Bool = false) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyChar = event.charactersIgnoringModifiers?.lowercased()
        
        // 1. Command + Option + 1 -> Cycle Display Mode (Desktop -> Floating -> Full Stage)
        // Replaces conflicting ⌘⇧L (which conflicts with Safari reading list / browser sidebar)
        if flags == [.command, .option] && (keyChar == "1" || event.keyCode == 18) {
            DispatchQueue.main.async {
                let current = AppSettings.shared.displayMode
                let next: WindowDisplayMode
                switch current {
                case .desktop: next = .floating
                case .floating: next = .fullStage
                case .fullStage: next = .desktop
                }
                AppSettings.shared.displayMode = next
            }
            return true
        }
        
        // 2. Command + Option + 2 -> Toggle Dynamic Notch Island
        // Replaces conflicting ⌘⇧N (which conflicts with Finder New Folder / Chrome Incognito)
        if flags == [.command, .option] && (keyChar == "2" || event.keyCode == 19) {
            DispatchQueue.main.async {
                AppSettings.shared.isNotchHUDEnabled.toggle()
            }
            return true
        }
        
        // 3. Command + Option + 3 -> Toggle Borderless Immersive Mode
        // Replaces conflicting ⌘⇧I (which conflicts with Chrome/Safari Developer Inspect)
        if flags == [.command, .option] && (keyChar == "3" || event.keyCode == 20) {
            DispatchQueue.main.async {
                AppSettings.shared.isImmersiveModeEnabled.toggle()
            }
            return true
        }
        
        // 4. Command + Option + 4 -> Toggle Multi-Zone Ambilight Bezel
        // Numbered shortcut: doesn't clash with screenshot ⌘⇧4
        if flags == [.command, .option] && (keyChar == "4" || event.keyCode == 21) {
            DispatchQueue.main.async {
                AppSettings.shared.isBezelEnabled.toggle()
            }
            return true
        }
        
        // 5. Command + Option + 5 -> Toggle Live Lyric AI Translation
        // Numbered shortcut: doesn't clash with screen recording ⌘⇧5
        if flags == [.command, .option] && (keyChar == "5" || event.keyCode == 23) {
            DispatchQueue.main.async {
                AppSettings.shared.isTranslationEnabled.toggle()
            }
            return true
        }
        
        // 6. Command + Option + 0 -> Reset Lyric Sync Offset to 0ms
        if flags == [.command, .option] && (keyChar == "0" || event.keyCode == 29) {
            DispatchQueue.main.async {
                AppSettings.shared.resetTimingOffset()
            }
            return true
        }
        
        // 7. Command + Option + K -> Toggle Command Palette Overlay
        // Replaces conflicting ⌘K (which hijacks Slack/VS Code quick open)
        if flags == [.command, .option] && keyChar == "k" {
            DispatchQueue.main.async {
                CommandPalettePanel.shared.toggle()
            }
            return true
        }
        
        // 8. Command + Option + RightArrow or Command + Option + 9 -> Cycle Lyric Themes
        if flags == [.command, .option] && (event.keyCode == 124 || keyChar == "9" || event.keyCode == 25) {
            DispatchQueue.main.async {
                let all = LyricStyle.allCases
                let idx = all.firstIndex(of: AppSettings.shared.lyricStyle) ?? 0
                AppSettings.shared.lyricStyle = all[(idx + 1) % all.count]
            }
            return true
        }
        
        // When Command Palette is visible and local, delegate key handling to it
        if isLocal && CommandPalettePanel.shared.isVisible {
            return false
        }
        
        let isEditingText = isLocal && (event.window?.firstResponder is NSText || event.window?.firstResponder is NSTextView)
        
        // 9. Command + Option + [ or (local palette) [ -> Instant Lyric Sync Offset Nudge -100ms
        // Replaces conflicting ⌘[ (which triggers browser Back in Safari/Chrome)
        if (flags == [.command, .option] && event.charactersIgnoringModifiers == "[") ||
           (isLocal && flags.isEmpty && !isEditingText && event.charactersIgnoringModifiers == "[") {
            DispatchQueue.main.async {
                AppSettings.shared.nudgeTimingOffset(by: -0.10)
            }
            return true
        }
        
        // 10. Command + Option + ] or (local palette) ] -> Instant Lyric Sync Offset Nudge +100ms
        // Replaces conflicting ⌘] (which triggers browser Forward in Safari/Chrome)
        if (flags == [.command, .option] && event.charactersIgnoringModifiers == "]") ||
           (isLocal && flags.isEmpty && !isEditingText && event.charactersIgnoringModifiers == "]") {
            DispatchQueue.main.async {
                AppSettings.shared.nudgeTimingOffset(by: 0.10)
            }
            return true
        }
        
        // 11. Command + Option + Space -> Media Play/Pause
        if flags == [.command, .option] && event.keyCode == 49 { // 49 = Space
            PlaybackManager.shared.togglePlayPause()
            return true
        }
        
        return false
    }
    
    private func startIdleTimer() {
        idleCheckTimer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkUserInactivity()
            }
    }
    
    private func checkUserInactivity() {
        guard isIdleScreensaverEnabled else { return }
        let isPlaying = PlaybackManager.shared.currentTrack.isPlaying
        let anyEvent = CGEventType(rawValue: ~0) ?? .mouseMoved
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
        
        if isPlaying && idleTime >= idleThresholdSeconds && !isCurrentlyInAutoScreensaver {
            // User has been idle for > 60s while music is playing -> Activate Full Stage Screensaver
            previousDisplayMode = AppSettings.shared.displayMode
            if previousDisplayMode != .fullStage {
                isCurrentlyInAutoScreensaver = true
                AppSettings.shared.displayMode = .fullStage
                OverlayWindowManager.shared.setDisplayMode(.fullStage)
            }
        } else if isCurrentlyInAutoScreensaver && idleTime < 2.0 {
            // User moved mouse or typed -> restore previous window placement
            isCurrentlyInAutoScreensaver = false
            AppSettings.shared.displayMode = previousDisplayMode
            OverlayWindowManager.shared.setDisplayMode(previousDisplayMode)
        }
    }
}
