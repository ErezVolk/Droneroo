//  Created by Erez Volk

import Foundation
import SwiftUI

/// A "tour of the app" with popovers
@Observable
class Tour {
    @Observable
    class Flag {
        var shown = false
    }

    var inProgress = false
    @ObservationIgnored private let keys: [String]
    @ObservationIgnored private let flags: [Flag]
    @ObservationIgnored private var index = 0

    init(_ keys: [String]) {
        self.keys = keys
        self.flags = keys.map { _ in Flag() }
    }

    /// Start or abort the tour
    func toggle() {
        if inProgress {
            stopTheTour()
        } else {
            startTheTour()
        }
    }

    private func startTheTour() {
        inProgress = true
        index = 0
        self.toggleCurrent()
    }

    func stopTheTour() {
        guard inProgress else { return }
        flags.forEach { flag in
            flag.shown = false
        }
        inProgress = false
    }

    /// Get a `Binding<Bool>` for the "show" state of a named item
    func get(_ key: String) -> Binding<Bool> {
        let index = self.keys.firstIndex(of: key)!
        let flag = self.flags[index]
        return Binding(
            get: { flag.shown },
            set: { flag.shown = $0 }
        )
    }

    /// Done with the current item, go to the next (if there is one)
    func next() {
        guard inProgress else { return }
        self.toggleCurrent()
        index += 1
        if index < flags.count {
            self.toggleCurrent()
        } else {
            stopTheTour()
        }
    }

    private func toggleCurrent() {
        flags[index].shown.toggle()
    }
}

extension View {
    /// Add a popover to this `View` and register to the tour
    func addToTour(_ tour: Tour, _ key: String, _ text: String) -> some View {
        return popover(isPresented: tour.get(key)) {
            Text(text)
                .padding()
                .presentationBackground(.thinMaterial)
                .presentationCompactAdaptation(.popover) // Needed for the first popover on iOS
                .onTapGesture { tour.next() }
        }
        .presentationCompactAdaptation(.popover) // Needed for the non-first popover on iOS
    }
}
