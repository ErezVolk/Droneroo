//  Created by Erez Volk

import SwiftUI

extension View {
    /// Make a button show only the image, without an outline

    func plainButton() -> some View {
#if os(macOS)
        return buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .fixedSize()
#else
        return labelStyle(.iconOnly)
#endif
    }
}
