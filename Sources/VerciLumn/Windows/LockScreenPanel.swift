import AppKit
import SwiftUI

public enum WindowDisplayMode: String, CaseIterable, Identifiable {
    case fullStage = "Full Stage Immersion (Entire Screen)"
    case lockScreenAndStage = "Lock Screen & Full Stage"
    case desktop = "Desktop (Behind All Apps)"
    case floating = "Floating Top Overlay"
    
    public var id: String { rawValue }
}

public final class LockScreenPanel: NSPanel {
    public private(set) var displayMode: WindowDisplayMode = .fullStage
    public private(set) var isScreenLocked: Bool = false
    
    public init(contentView: NSView, screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
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
        self.ignoresMouseEvents = true
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
        dnc.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        dnc.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }
    
    @objc private func screenLocked() {
        isScreenLocked = true
        updateWindowLevel()
    }
    
    @objc private func screenUnlocked() {
        isScreenLocked = false
        updateWindowLevel()
    }
    
    public func updateWindowLevel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Screen Saver / Lock Screen elevation priority (macOS Sonoma/Sequoia compatible)
            let lockScreenLevel = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
            
            if self.isScreenLocked {
                self.level = lockScreenLevel
                self.orderFrontRegardless()
                return
            }
            
            switch self.displayMode {
            case .fullStage:
                // Covers the full monitor above wallpaper, interactive stage
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) - 1)
                self.orderFrontRegardless()
            case .lockScreenAndStage:
                self.level = lockScreenLevel
                self.orderFrontRegardless()
            case .desktop:
                // Sits behind all applications on the desktop
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
                self.orderBack(nil)
            case .floating:
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
                self.orderFrontRegardless()
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
