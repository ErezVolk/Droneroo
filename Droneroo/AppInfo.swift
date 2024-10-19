//  Created by Erez Volk

import CoreFoundation
import Foundation
import SwiftUI

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

struct InfoView: View {
    var body: some View {
        Link(getWhoAmI(), destination: URL(string: "https://github.com/ErezVolk/Droneroo")!)
            .font(.caption)
            .opacity(0.7)
    }
}
