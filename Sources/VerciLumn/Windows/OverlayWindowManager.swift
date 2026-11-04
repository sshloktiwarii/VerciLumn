import AppKit
import SwiftUI

public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    private var panels: [LockScreenPanel] = []
    @Published public private(set) var currentMode: WindowDisplayMode = .desktop
    
    private init() {}
    
    public func setupOverlays<Content: View>(rootView: Content, mode: WindowDisplayMode = .desktop) {
        closeOverlays()
        self.currentMode = mode
        
        let screens = NSScreen.screens
        for screen in screens {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = screen.frame
            let panel = LockScreenPanel(contentView: hostingView, screen: screen)
            panel.setDisplayMode(mode)
            panels.append(panel)
        }
    }
    
    public func setDisplayMode(_ mode: WindowDisplayMode) {
        self.currentMode = mode
        for panel in panels {
            panel.setDisplayMode(mode)
        }
    }
    
    public func closeOverlays() {
        for panel in panels {
            panel.close()
        }
        panels.removeAll()
    }
}
