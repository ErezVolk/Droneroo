//  Created by Erez Volk

import SwiftUI

extension View {
    /// Convenience wrapper around `.onKeyPress` so `action` can be a one-liner.
    func handleKey(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        return self.onKeyPress(key) {
            action()
            return .handled
        }
    }
}
