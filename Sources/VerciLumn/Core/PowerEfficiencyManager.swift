import Foundation
import Combine
import AppKit

/// Observes macOS Low Power Mode and thermal states to automatically throttle or suspend
/// GPU Metal rendering and audio capture, switching to a battery-efficient static display.
public final class PowerEfficiencyManager: ObservableObject {
    public static let shared = PowerEfficiencyManager()
    
    @Published public private(set) var isLowPowerModeEnabled: Bool = false
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.thermalState = ProcessInfo.processInfo.thermalState
        setupObservers()
        applyPowerPolicy()
    }
    
    private func setupObservers() {
        // Observe macOS Low Power Mode state changes
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.handlePowerStateChange()
                }
            }
            .store(in: &cancellables)
            
        // Observe macOS Thermal pressure state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.handleThermalStateChange()
                }
            }
            .store(in: &cancellables)
    }
    
    public func handlePowerStateChange() {
        let isLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.isLowPowerModeEnabled = isLPM
        applyPowerPolicy()
    }
    
    public func handleThermalStateChange() {
        let state = ProcessInfo.processInfo.thermalState
        self.thermalState = state
        applyPowerPolicy()
    }
    
    private func applyPowerPolicy() {
        let shouldThrottle = isLowPowerModeEnabled || thermalState == .serious || thermalState == .critical
        
        // 1. Suspend Metal shader renderer
        MetalShaderRenderer.shared.isSuspended = shouldThrottle
        
        // 2. Adjust target FPS interval in settings for battery preservation
        DispatchQueue.main.async {
            AppSettings.shared.isLowPowerModeEnabled = shouldThrottle
        }
    }
    
    /// Test helper to simulate power mode changes
    public func setSimulatedLowPowerMode(_ enabled: Bool) {
        self.isLowPowerModeEnabled = enabled
        applyPowerPolicy()
    }
}
