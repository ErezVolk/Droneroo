//  Created by Erez Volk

import SwiftUI

extension View {
    /// Make a button show only the image, without an outline
    func plainButton() -> some View {
        return buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .fixedSize()
    }
}
