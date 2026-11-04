import AppKit
import SwiftUI

public enum WindowDisplayMode: String, CaseIterable, Identifiable {
    case fullStage = "Full Stage Immersion (Entire Screen)"
    case lockScreenAndStage = "Lock Screen Only (Shows when locked)"
    case desktop = "Desktop Wallpaper (Behind all apps)"
    case floating = "Floating Top Overlay"
    
    public var id: String { rawValue }
}

public final class InteractivePassThroughHostingView<Content: View>: NSHostingView<Content> {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let isTransparent = AppSettings.shared.backdropMode == .transparent
        
        // If not transparent (i.e. solid dark stage like Tunnel, Particles, OLED),
        // the visualizer controls and canvas are active and receive clicks directly.
        if !isTransparent {
            return super.hitTest(point)
        }
        
        // If transparent pass-through mode:
        // AppKit coordinates: (0, 0) is at bottom-left of the view.
        let h = bounds.height
        let w = bounds.width
        guard h > 0, w > 0 else { return super.hitTest(point) }
        
        // 1. Bottom Dock region (y: 0 to 140): Intercept clicks for scrubber and Now Playing card
        if point.y <= 140 {
            return super.hitTest(point)
        }
        
        // 2. Center Lyrics region (y: 22% to 78%, x: 10% to 90%): Intercept clicks for lyrics rewind/skip/seek
        let lyricYMin = h * 0.22
        let lyricYMax = h * 0.78
        let lyricXMin = w * 0.10
        let lyricXMax = w * 0.90
        if point.y >= lyricYMin && point.y <= lyricYMax && point.x >= lyricXMin && point.x <= lyricXMax {
            return super.hitTest(point)
        }
        
        // Outside interactive areas in transparent mode: pass click through to desktop/background apps
        return nil
    }
}

public final class LockScreenPanel: NSPanel {
    public private(set) var displayMode: WindowDisplayMode = .fullStage
    public private(set) var isScreenLocked: Bool = false
    
    public init(contentView: NSView, screen: NSScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false
        self.canHide = false
        self.contentView = contentView
        
        setupLockNotifications()
        updateWindowLevel()
    }
    
    public func setDisplayMode(_ mode: WindowDisplayMode) {
        self.displayMode = mode
        updateWindowLevel()
    }
    
    private func setupLockNotifications() {
        let dnc = DistributedNotificationCenter.default()
        
        // Immediate delivery is required for accessory/background apps without active key windows
        let lockEvents = [
            "com.apple.screenIsLocked",
            "com.apple.lockComplete",
            "com.apple.screensaver.didstart"
        ]
        
        for event in lockEvents {
            dnc.addObserver(
                self,
                selector: #selector(screenLocked),
                name: NSNotification.Name(event),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
        
        let unlockEvents = [
            "com.apple.screenIsUnlocked",
            "com.apple.screensaver.didstop"
        ]
        
        for event in unlockEvents {
            dnc.addObserver(
                self,
                selector: #selector(screenUnlocked),
                name: NSNotification.Name(event),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
        
        // Workspace session & sleep notifications for power button and fast sleep
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }
    
    @objc public func screenLocked() {
        isScreenLocked = true
        OverlayWindowManager.shared.setScreenLocked(true)
        updateWindowLevel()
    }
    
    @objc public func screenUnlocked() {
        isScreenLocked = false
        OverlayWindowManager.shared.setScreenLocked(false)
        updateWindowLevel()
    }
    
    public func updateWindowLevel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // On macOS Sonoma & Sequoia, loginwindow shields at CGShieldingWindowLevel()
            let lockScreenShieldLevel = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
            
            if self.isScreenLocked {
                self.level = lockScreenShieldLevel
                self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                self.orderFrontRegardless()
                return
            }
            
            switch self.displayMode {
            case .fullStage:
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) - 1)
                self.orderFrontRegardless()
            case .lockScreenAndStage:
                // When unlocked, hide completely if user set lock screen only
                self.orderOut(nil)
            case .desktop:
                // Sits above wallpaper picture, behind all normal applications on the desktop
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
                self.orderFront(nil)
            case .floating:
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
                self.orderFrontRegardless()
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

