import Foundation
import IOKit.pwr_mgt

public final class DisplaySleepManager {
    public static let shared = DisplaySleepManager()
    
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0
    private var hasActiveAssertion: Bool = false
    
    private init() {}
    
    public func setPreventDisplaySleep(_ prevent: Bool, reason: String = "VerciLumn Active Playback") {
        if prevent {
            guard !hasActiveAssertion else { return }
            
            // Prevent display from dimming or sleeping
            let displayResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &displayAssertionID
            )
            
            // Prevent CPU from sleeping during lock screen playback
            let systemResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &systemAssertionID
            )
            
            if displayResult == kIOReturnSuccess || systemResult == kIOReturnSuccess {
                hasActiveAssertion = true
            }
        } else {
            guard hasActiveAssertion else { return }
            if displayAssertionID != 0 {
                IOPMAssertionRelease(displayAssertionID)
                displayAssertionID = 0
            }
            if systemAssertionID != 0 {
                IOPMAssertionRelease(systemAssertionID)
                systemAssertionID = 0
            }
            hasActiveAssertion = false
        }
    }
    
    deinit {
        if hasActiveAssertion {
            if displayAssertionID != 0 { IOPMAssertionRelease(displayAssertionID) }
            if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        }
    }
}


