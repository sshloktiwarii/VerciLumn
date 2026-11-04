import AppKit
import SwiftUI
import Combine

public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    private var panels: [LockScreenPanel] = []
    private var notchPanel: DynamicNotchPanel?
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var currentMode: WindowDisplayMode = .desktop
    @Published public private(set) var isScreenLocked: Bool = false
    
    private init() {
        // Observe AppSettings for Notch HUD toggle
        AppSettings.shared.$isNotchHUDEnabled
            .sink { [weak self] enabled in
                self?.setNotchHUDVisible(enabled)
            }
            .store(in: &cancellables)
    }
    
    public func setScreenLocked(_ locked: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isScreenLocked = locked
        }
    }
    
    public func setupOverlays<Content: View>(rootView: Content, mode: WindowDisplayMode = .desktop) {
        closeOverlays()
        self.currentMode = mode
        
        let screens = NSScreen.screens
        for screen in screens {
            let hostingView = InteractivePassThroughHostingView(rootView: rootView)
            hostingView.frame = screen.frame
            let panel = LockScreenPanel(contentView: hostingView, screen: screen)
            panel.setDisplayMode(mode)
            panels.append(panel)
        }
        
        setupNotchPanel()
    }
    
    public func setupNotchPanel() {
        if notchPanel == nil {
            notchPanel = DynamicNotchPanel()
        }
        setNotchHUDVisible(AppSettings.shared.isNotchHUDEnabled)
    }
    
    public func setNotchHUDVisible(_ visible: Bool) {
        if visible {
            if notchPanel == nil {
                notchPanel = DynamicNotchPanel()
            }
            notchPanel?.updatePosition()
            notchPanel?.orderFront(nil)
        } else {
            notchPanel?.orderOut(nil)
        }
    }
    
    public func updateScreenLayout() {
        for panel in panels {
            panel.updateWindowLevel()
        }
        notchPanel?.updatePosition()
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
        notchPanel?.close()
        notchPanel = nil
    }
}
