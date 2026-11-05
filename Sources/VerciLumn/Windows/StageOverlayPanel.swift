import AppKit
import SwiftUI

public enum WindowDisplayMode: String, CaseIterable, Identifiable {
    case fullStage = "Full Stage Immersion (Entire Screen)"
    case desktop = "Desktop Wallpaper (Behind all apps)"
    case floating = "Floating Top Overlay"
    
    public var id: String { rawValue }
}

/// Hosting view designed for click pass-through to background macOS apps
public final class InteractivePassThroughHostingView<Content: View>: NSHostingView<Content> {
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.isOpaque = false
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let isFloating = AppSettings.shared.displayMode == .floating
        let isTransparent = AppSettings.shared.backdropMode == .transparent
        
        // 1. Floating Overlay Mode: Intercept clicks strictly inside the draggable / resizable floating pod
        if isFloating {
            if let swiftUIRect = OverlayWindowManager.shared.floatingWidgetRect {
                let h = bounds.height
                // Convert SwiftUI (top-left origin) to AppKit (bottom-left origin) with an 8px generous margin
                let appKitRect = NSRect(
                    x: swiftUIRect.origin.x - 8,
                    y: h - swiftUIRect.origin.y - swiftUIRect.height - 8,
                    width: swiftUIRect.width + 16,
                    height: swiftUIRect.height + 16
                )
                if appKitRect.contains(point) {
                    return super.hitTest(point)
                }
            }
            // Outside the floating pod in floating mode: strictly pass clicks through to background apps
            return nil
        }
        
        // 2. Transparent Full Stage Mode: pass-through with interactive center lyrics and bottom dock
        if isTransparent {
            let h = bounds.height
            let w = bounds.width
            guard h > 0, w > 0 else { return nil }
            
            // Bottom Dock region (y: 0 to 140)
            if point.y <= 140 {
                return super.hitTest(point)
            }
            
            // Center Lyrics region (y: 22% to 78%, x: 10% to 90%)
            let lyricYMin = h * 0.22
            let lyricYMax = h * 0.78
            let lyricXMin = w * 0.10
            let lyricXMax = w * 0.90
            if point.y >= lyricYMin && point.y <= lyricYMax && point.x >= lyricXMin && point.x <= lyricXMax {
                return super.hitTest(point)
            }
            
            return nil
        }
        
        // 3. Solid Stage: full interactive
        return super.hitTest(point)
    }
}

/// Production-grade stage overlay window adhering strictly to Apple macOS WindowServer guidelines.
/// Replaces legacy LockScreenPanel hacks (no CGShieldingWindowLevel manipulation).
public final class StageOverlayPanel: NSPanel {
    public private(set) var displayMode: WindowDisplayMode = .desktop
    public private(set) weak var targetScreen: NSScreen?
    
    public init(contentView: NSView, screen: NSScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()) {
        self.targetScreen = screen
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
        
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false
        
        // Strict NSWindow-level click-through enforcement for visual overlays
        self.ignoresMouseEvents = (AppSettings.shared.backdropMode == .transparent)
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false
        self.canHide = false
        self.contentView = contentView
        
        expandToScreenBounds()
        updateWindowLevel()
    }
    
    public func setDisplayMode(_ mode: WindowDisplayMode) {
        self.displayMode = mode
        updateWindowLevel()
    }
    
    public func setIgnoresMouseEventsStrict(_ ignore: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.ignoresMouseEvents = ignore
        }
    }
    
    /// Expands the panel to the absolute physical display bounds, ignoring safe areas (camera notch / dock / menu bar)
    public func expandToScreenBounds() {
        let screenToUse = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let target = screenToUse else { return }
        let fullFrame = target.frame
        self.setFrame(fullFrame, display: true)
        self.contentView?.frame = NSRect(origin: .zero, size: fullFrame.size)
    }
    
    public func updateWindowLevel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.displayMode {
            case .fullStage:
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) - 1)
                self.orderFrontRegardless()
            case .desktop:
                // Sits strictly above desktop wallpaper & shadow, strictly behind all normal user applications
                self.level = NSWindow.Level(rawValue: -1)
                self.orderFront(nil)
            case .floating:
                // Elevated strictly above normal application windows and floating panels (level 4)
                self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
                self.orderFrontRegardless()
            }
        }
    }
    
    public override var canBecomeKey: Bool {
        return AppSettings.shared.isImmersiveModeEnabled && self.displayMode != .floating
    }
    
    public override var canBecomeMain: Bool {
        return AppSettings.shared.isImmersiveModeEnabled && self.displayMode != .floating
    }
}

