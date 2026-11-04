import AppKit
import SwiftUI

public final class LockScreenPanel: NSPanel {
    public init(contentView: NSView, screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Elevate above system lock screen and screen saver
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
        self.contentView = contentView
    }
}
