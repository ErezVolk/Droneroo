//  Created by Erez Volk
import SwiftUI

func pickSoundFont() -> URL? {
#if os(macOS)
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
        return panel.url!
    }
#endif
    return nil
}
