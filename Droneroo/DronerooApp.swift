// Created by Erez Volk.

import SwiftUI

@main
struct DronerooApp: App {
    @StateObject var state = DronerooState.shared

    var body: some Scene {
        WindowGroup {
            DronerooView().id(state.dronerooID)
        }
    }
}
