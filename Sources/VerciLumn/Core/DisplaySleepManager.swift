import Foundation
import IOKit.pwr_mgt

public final class DisplaySleepManager {
    public static let shared = DisplaySleepManager()
    
    private var assertionID: IOPMAssertionID = 0
    private var hasActiveAssertion: Bool = false
    
    private init() {}
    
    public func setPreventDisplaySleep(_ prevent: Bool, reason: String = "VerciLumn Active Playback") {
        if prevent {
            guard !hasActiveAssertion else { return }
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess {
                hasActiveAssertion = true
            }
        } else {
            guard hasActiveAssertion else { return }
            IOPMAssertionRelease(assertionID)
            hasActiveAssertion = false
            assertionID = 0
        }
    }
    
    deinit {
        if hasActiveAssertion {
            IOPMAssertionRelease(assertionID)
        }
    }
}

