//  Created by Erez Volk

import SwiftUI

/// Slider with the label visible (on iPhone it isn't)
struct LabeledSlider: View {
    let value: Binding<Double>
    let low: String
    let high: String
    let help: String
    let propagate: () -> Void

    var body: some View {
        HStack {
            sliderLabel("Minimum \(help)", systemImage: low)
            Slider(value: value, in: 0...1) {
                EmptyView()
            } onEditingChanged: { isEditing in
                if !isEditing {
                    propagate()
                }
            }
            sliderLabel("Maximum \(help)", systemImage: low)
        }
        .padding(.horizontal)
        .onAppear { propagate() }
    }

    func sliderLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage).labelStyle(.iconOnly)
    }
}
