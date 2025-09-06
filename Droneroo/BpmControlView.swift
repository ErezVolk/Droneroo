//  Created by Erez Volk

import SwiftUI
import Combine

/// A View to a metronome.
/// Based on https://medium.com/@anik1.bd_38552/swiftui-circular-slider-f713a2b28779
/// TODO: Upside-down
/// TODO: Add tick marks
/// TODO: Make pretttier
/// TODO: Leave space at top
/// TODO: Work on iPad (iOS in general?)
struct BpmControlView: View {
    @Binding var bpm: Double
    @Binding var isOn: Bool
    @State var knobAngleDeg: CGFloat = 0.0
    private let minBpm: Double = 30
    private let maxBpm: Double = 300
    private let diameter: Int = 100
#if os(iOS)
    private let knobRadius: CGFloat = 12
#else
    private let knobRadius: CGFloat = 6
#endif
    
    var body: some View {
        HStack {
            Button("Half", systemImage: "divide.circle") { bpmToKnob(factor: 0.5) }
                .imageScale(.large)
                .plainButton()
            Button("Slower", systemImage: "minus.circle") { bpmToKnob(-1) }
                .imageScale(.large)
                .plainButton()
            
            ZStack {
                Toggle("♩=\(Int(bpm))", isOn: $isOn)
                    .toggleStyle(EncircledToggleStyle(
                        diameter: diameter,
                        bold: isOn,
                        onTextColor: .drGreen4,
                        onBackColor: .drGrey8,
                        offTextColor: .drGreen3,
                        offBackColor: .drGrey7
                    ))
                    .onTapGesture { isOn.toggle() }
                
                Circle()
                    .trim(from: 0.0, to: (bpm - minBpm) / (maxBpm - minBpm))
                    .stroke(Color.drGrey4, lineWidth: 4)
                    .frame(width: CGFloat(diameter), height: CGFloat(diameter))
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .stroke(Color.drGrey4, lineWidth: 1)
                    .fill(Color.drGrey5)
                    .frame(width: knobRadius * 2, height: knobRadius * 2)
                    .padding(10)
                    .offset(y: CGFloat(-diameter / 2))
                    .rotationEffect(Angle.degrees(Double(knobAngleDeg)))
                    .gesture(DragGesture(minimumDistance: 0.0)
                        .onChanged({ value in
                            knobToBpm(location: value.location)
                        }))
            }
            
            Button("Faster", systemImage: "plus.circle") { bpmToKnob(1) }
                .imageScale(.large)
                .plainButton()
            Button("Double", systemImage: "multiply.circle") { bpmToKnob(factor: 2) }
                .imageScale(.large)
                .plainButton()        }
        .onAppear {
            bpmToKnob()
        }
    }

    private func bpmToKnob(_ delta: Double = 0, factor: Double = 1) {
        let newBpm = (bpm * factor) + delta
        bpm = min(max(newBpm.rounded(), minBpm), maxBpm)
        knobAngleDeg = (bpm - minBpm) / (maxBpm - minBpm) * 360.0
    }
    
    /// TODO: Rewrite
    private func knobToBpm(location: CGPoint) {
        // creating vector from location point
        let vector = CGVector(dx: location.x, dy: location.y)
        
        // geting angle in radian need to subtract the knob radius and padding from the dy and dx
        let angleRad = atan2(vector.dy - (knobRadius + 10), vector.dx - (knobRadius + 10)) + .pi/2.0
        
        // convert angle range from (-pi to pi) to (0 to 2pi)
        let fixedAngleRad = angleRad < 0.0 ? angleRad + 2.0 * .pi : angleRad
        // convert angle value to temperature value
        let newBpm = fixedAngleRad / (2.0 * .pi) * (maxBpm - minBpm) + minBpm
        // convert angle to degree
        let newAngleDeg = fixedAngleRad * 180 / .pi
        
        if (newAngleDeg > 270 && knobAngleDeg < 90) || (newAngleDeg < 90 && knobAngleDeg > 270) {
            return
        }
        
        guard newBpm >= minBpm && newBpm <= maxBpm else { return }
        
        bpm = newBpm
        knobAngleDeg = newAngleDeg
    }
}
