//  Created by Erez Volk

import SwiftUI
import Combine
import UniformTypeIdentifiers

enum Instrument: String, CaseIterable, Identifiable {
    case strings = "Strings"
    case beep = "Beep"
    var id: String { self.rawValue }
}
