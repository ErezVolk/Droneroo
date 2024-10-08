//  Created by Erez Volk

import CoreFoundation
import Foundation

/// Just for fun, figure out our name and version programmatically
func getWhoAmI() -> String {
    guard let props = Bundle.main.infoDictionary else { return "???" }

    func prop(_ key: String) -> String {
        return props[key] as? String ?? "???"
    }

    let app = prop(kCFBundleNameKey as String)
    let ver = prop("CFBundleShortVersionString")
    return "\(app) v\(ver)"
}
