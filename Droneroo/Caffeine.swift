//  Created by Erez Volk

import Foundation
#if os(iOS)
import UIKit

class Caffeine {
    func stayUp(_ state: Bool) {
        UIApplication.shared.isIdleTimerDisabled = state
    }
}
#else

class Caffeine {
    private var assertionID: IOPMAssertionID = 0

    func stayUp(_ state: Bool) {
        guard state != (assertionID != 0) else { return }
        if state {
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Droneroo" as CFString,
                &assertionID)
            if status != kIOReturnSuccess {
                print("Cannot disable sleep: \(status)")
                assertionID = 0
            }
        } else {
            let status = IOPMAssertionRelease(assertionID)
            if status == kIOReturnSuccess {
                assertionID = 0
            } else {
                print("Cannot re-enable sleep: \(status)")
            }
        }
    }
}
#endif
