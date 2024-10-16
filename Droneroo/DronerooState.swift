//  Created by Erez Volk

import SwiftUI

/// A way to reset all defaults
/// https://stackoverflow.com/questions/65309064
/// https://ohmyswift.com/blog/2020/05/19/an-effective-way-to-clear-entire-userdefaults-in-swift/
class DronerooState: ObservableObject {
    static let shared = DronerooState()

    @Published var dronerooID = UUID()

    func reset() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        dronerooID = UUID()
    }
}
