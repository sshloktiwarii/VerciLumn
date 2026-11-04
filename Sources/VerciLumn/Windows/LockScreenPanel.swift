import AppKit
import SwiftUI

public enum WindowDisplayMode: String, CaseIterable, Identifiable {
    case desktop = "Desktop (Behind Apps)"
    case alwaysOnTop = "Floating (Above All Apps)"
    case lockScreenOnly = "Lock Screen Only"
    
    public var id: String { rawValue }
}

public final class LockScreenPanel: NSPanel {
    public private(set) var displayMode: WindowDisplayMode = .desktop
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
            if self.isScreenLocked {
                // Elevate over lock screen
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
                self.orderFrontRegardless()
            } else {
                switch self.displayMode {
                case .desktop:
                    // Sits behind all applications on the desktop
                    self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
                    self.orderBack(nil)
                case .alwaysOnTop:
                    self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)))
                    self.orderFrontRegardless()
                case .lockScreenOnly:
                    self.orderOut(nil)
                }
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
