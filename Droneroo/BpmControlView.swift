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
    private let standardBpms: [Double] = [
        // https://en.wikipedia.org/wiki/Metronome#Usage
        40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60,
        63, 66, 69, 72,
        76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116, 120,
        126, 132, 138, 144,
        152, 160, 168, 176, 184, 192, 200, 208,
    ]
    private let diameter: Int = 100
#if os(iOS)
    private let knobRadius: CGFloat = 12
#else
    private let knobRadius: CGFloat = 6
#endif
    
    var body: some View {
        HStack {
            HStack {
                Button("Previous", systemImage: "chevron.left.circle") { prevStandardBpm() }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm <= standardBpms.first!)
                Button("Half", systemImage: "divide.circle") { bpmToKnob(factor: 0.5) }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm <= minBpm)
                Button("Slower", systemImage: "minus.circle") { bpmToKnob(-1) }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm <= minBpm)
            }
            
            ZStack {
                if #available(macOS 26.0, iOS 26.0, *) {
                    ZStack {
                        Circle()
                            .frame(width: CGFloat(diameter), height: CGFloat(diameter))
                            .foregroundStyle(isOn ? .drGrey8 : .drGrey7)
                        Text("♩=\(Int(bpm))")
                            .font(.largeTitle.pointSize(CGFloat(diameter) / 4).bold(isOn))
                    }
                    .onTapGesture { isOn.toggle() }
                } else {
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
                }
                
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
            
            HStack {
                Button("Faster", systemImage: "plus.circle") { bpmToKnob(1) }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm >= maxBpm)
                Button("Double", systemImage: "multiply.circle") { bpmToKnob(factor: 2) }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm >= maxBpm)
                Button("Next", systemImage: "chevron.right.circle") { nextStandardBpm() }
                    .imageScale(.large)
                    .plainButton()
                    .disabled(bpm >= standardBpms.last!)
            }
        }
        .onAppear {
            bpmToKnob()
        }
    }
    
    private func prevStandardBpm() {
        if let nextBpm = standardBpms.last(where: { $0 < bpm }) {
            bpm = nextBpm;
            bpmToKnob();
        }
    }
    
    private func nextStandardBpm() {
        if let nextBpm = standardBpms.first(where: { $0 > bpm }) {
            bpm = nextBpm;
            bpmToKnob();
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
