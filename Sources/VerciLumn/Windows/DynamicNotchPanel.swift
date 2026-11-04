import AppKit
import SwiftUI

public final class DynamicNotchPanel: NSPanel {
    public init(screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 90
        
        let screenFrame = screen.frame
        let notchX = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let notchY = screenFrame.origin.y + screenFrame.height - panelHeight
        
        let rect = NSRect(x: notchX, y: notchY, width: panelWidth, height: panelHeight)
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.canHide = false
        
        let hostingView = NSHostingView(rootView: DynamicNotchHUDView())
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        self.contentView = hostingView
    }
    
    public override var canBecomeKey: Bool {
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public func updatePosition(for screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 90
        let screenFrame = screen.frame
        let notchX = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let notchY = screenFrame.origin.y + screenFrame.height - panelHeight
        self.setFrame(NSRect(x: notchX, y: notchY, width: panelWidth, height: panelHeight), display: true)
    }
}

