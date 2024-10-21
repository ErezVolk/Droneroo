//  Created by Erez Volk

import SwiftUI

struct Encircled: ViewModifier {
    let diameter: CGFloat

    func body(content: Content) -> some View {
        return Circle()
            .frame(width: diameter, height: diameter)
            .overlay { content }
    }
}

extension View {
    func encircle(diameter: Int = 104,
                  shadowRadius: CGFloat = 3,
                  textColor: Color,
                  circleColor: Color,
                  textFont: Font? = nil,
                  bold: Bool = false) -> some View {
        font(textFont ?? .system(size: CGFloat(diameter / 4)))
            .bold(bold)
            .foregroundColor(textColor)
            .modifier(Encircled(diameter: CGFloat(diameter)))
            .shadow(radius: shadowRadius)
            .foregroundColor(circleColor)
    }
}

struct EncircledToggleStyle: ToggleStyle {
    var diameter = 128
    var onRadius: CGFloat = 10
    var offRadius: CGFloat = 3
    var textFont: Font?
    var bold: Bool = false
    var onTextColor: Color
    var onBackColor: Color
    var offTextColor: Color
    var offBackColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .encircle(
                diameter: self.diameter,
                shadowRadius: configuration.isOn ? onRadius: offRadius,
                textColor: configuration.isOn ? onTextColor : offTextColor,
                circleColor: configuration.isOn ? onBackColor : offBackColor,
                textFont: self.textFont,
                bold: self.bold
            )
    }
}
