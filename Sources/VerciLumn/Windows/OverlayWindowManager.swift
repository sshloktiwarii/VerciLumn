import AppKit
import SwiftUI

public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    private var panels: [LockScreenPanel] = []
    
    private init() {}
    
    public func setupOverlays<Content: View>(rootView: Content) {
        closeOverlays()
        
        let screens = NSScreen.screens
        for screen in screens {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = screen.frame
            let panel = LockScreenPanel(contentView: hostingView, screen: screen)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }
    
    public func closeOverlays() {
        for panel in panels {
            panel.close()
        }
        panels.removeAll()
    }
}
