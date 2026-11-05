import AppKit
import SwiftUI
import Combine

public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    private var panels: [StageOverlayPanel] = []
    private var notchPanel: DynamicNotchPanel?
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var currentMode: WindowDisplayMode = .desktop
    @Published public private(set) var isScreenLocked: Bool = false
    @Published public private(set) var isImmersiveMode: Bool = false
    @Published public var floatingWidgetRect: CGRect?
    
    public func updateFloatingWidgetRect(_ rect: CGRect) {
        self.floatingWidgetRect = rect
    }
    
    private init() {
        // Observe AppSettings for Notch HUD toggle
        AppSettings.shared.$isNotchHUDEnabled
            .sink { [weak self] enabled in
                self?.setNotchHUDVisible(enabled)
            }
            .store(in: &cancellables)
            
        // Observe Backdrop changes to enforce NSWindow level click-through
        AppSettings.shared.$backdropMode
            .sink { [weak self] mode in
                self?.updateClickThroughBehavior(for: mode)
            }
            .store(in: &cancellables)
            
        // Observe Display Mode changes (fullStage, desktop, floating)
        AppSettings.shared.$displayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.setDisplayMode(mode)
            }
            .store(in: &cancellables)
            
        // Observe Immersive Mode (auto-hide Menu Bar and Dock without macOS Space slide)
        AppSettings.shared.$isImmersiveModeEnabled
            .sink { [weak self] enabled in
                self?.setImmersiveMode(enabled)
            }
            .store(in: &cancellables)
    }
    
    public func setScreenLocked(_ locked: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isScreenLocked = locked
        }
    }
    
    public func updateClickThroughBehavior(for mode: BackdropMode) {
        let isPassThrough = (mode == .transparent || currentMode == .floating)
        for panel in panels {
            panel.setIgnoresMouseEventsStrict(isPassThrough)
        }
    }
    
    public func setupOverlays<Content: View>(rootView: Content, mode: WindowDisplayMode = .desktop) {
        closeOverlays()
        self.currentMode = mode
        
        let screens = NSScreen.screens
        for screen in screens {
            let hostingView = InteractivePassThroughHostingView(rootView: rootView)
            hostingView.frame = screen.frame
            let panel = StageOverlayPanel(contentView: hostingView, screen: screen)
            panel.setDisplayMode(mode)
            panels.append(panel)
        }
        
        setupNotchPanel()
        
        if AppSettings.shared.isImmersiveModeEnabled {
            setImmersiveMode(true)
        }
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
            panel.expandToScreenBounds()
            panel.updateWindowLevel()
        }
        notchPanel?.updatePosition()
        
        if isImmersiveMode {
            NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        }
    }
    
    /// Borderless Full-Screen Immersion on the current Space:
    /// Auto-hides Menu Bar and Dock via NSApp.presentationOptions and expands panel to exact screen bounds.
    public func setImmersiveMode(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isImmersiveMode = enabled
            
            if enabled {
                NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.presentationOptions = []
            }
            
            for panel in self.panels {
                panel.expandToScreenBounds()
                panel.updateWindowLevel()
                if enabled && panel.displayMode != .floating {
                    panel.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    public func toggleImmersiveMode() {
        AppSettings.shared.isImmersiveModeEnabled.toggle()
    }
    
    public func setDisplayMode(_ mode: WindowDisplayMode) {
        self.currentMode = mode
        let isPassThrough = (AppSettings.shared.backdropMode == .transparent || mode == .floating)
        for panel in panels {
            panel.setIgnoresMouseEventsStrict(isPassThrough)
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
