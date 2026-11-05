import AppKit
import SwiftUI

public final class CommandPalettePanel: NSPanel {
    public static let shared = CommandPalettePanel()
    
    private var localKeyMonitor: Any?
    
    public init() {
        let width: CGFloat = 580
        let height: CGFloat = 420
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let screenFrame = screen.frame
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2 + 80 // slightly above vertical center
        
        let rect = NSRect(x: originX, y: originY, width: width, height: height)
        
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
        self.hidesOnDeactivate = false
        
        let hostingView = NSHostingView(rootView: CommandPaletteView(onClose: { [weak self] in
            self?.hide()
        }))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        self.contentView = hostingView
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    public func show() {
        updatePosition()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        startLocalKeyMonitor()
    }
    
    public func hide() {
        self.orderOut(nil)
        stopLocalKeyMonitor()
    }
    
    public func updatePosition(for screen: NSScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()) {
        let width: CGFloat = 580
        let height: CGFloat = 420
        let screenFrame = screen.frame
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2 + 80
        self.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
    }
    
    private func startLocalKeyMonitor() {
        stopLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            
            // Post notification for SwiftUI view navigation
            NotificationCenter.default.post(name: NSNotification.Name("CommandPaletteKeyDown"), object: event)
            
            // Intercept special keys
            if event.keyCode == 53 { // Escape
                self.hide()
                return nil
            }
            if event.keyCode == 125 || event.keyCode == 126 || event.keyCode == 36 { // Arrows, Enter
                return nil // handled by notification
            }
            if event.charactersIgnoringModifiers == "[" || event.charactersIgnoringModifiers == "]" {
                // Let notification or AppSettings handle timing nudge
                return nil
            }
            
            return event
        }
    }
    
    private func stopLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    public override func resignKey() {
        super.resignKey()
        hide()
    }
}
