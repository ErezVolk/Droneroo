//  Created by Erez Volk

import CoreFoundation
import Foundation

/// Helper to get a value from the bundle's info dictionary
fileprivate func getBundleProperty(_ key: CFString) -> String {
    return Bundle.main.infoDictionary?[key as String] as? String ?? "???"
}

/// Just for fun, figure out our name and version programmatically
func getWhoAmI() -> String {
    let app = getBundleProperty(kCFBundleNameKey)
    let ver = getBundleProperty("CFBundleShortVersionString" as CFString)
    return "\(app) v\(ver)"
}
