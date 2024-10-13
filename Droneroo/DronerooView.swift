// Created by Erez Volk.

import SwiftUI
import Combine
import UniformTypeIdentifiers

enum Instrument: String, CaseIterable, Identifiable {
    case strings = "Strings"
    case beep = "Beep"
    var id: String { self.rawValue }
}

extension View {
    /// Convenience wrapper around `.onKeyPress` so `action` can be a one-liner.
    func handleKey(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        return self.onKeyPress(key) {
            action()
            return .handled
        }
    }
}

struct DronerooView: View {
    @StateObject private var logic = DronerooLogic()
    @State private var selectedSequence: SequenceType = .circleOfFourth
    @FocusState private var focused: Bool
    /// How much to add to the current note index when the right arrow key is pressed ("forward")
    @State private var direction = 1
    // Since calling `audioManager` from `.onKeyPress` issues errors, save them aside
    @State private var toChangeNote = 0
    // Since calling `audioManager` from `.onTap` issues errors, save them aside
    @State private var toToggleDrone = false
    private let soundbankTypes = [UTType(filenameExtension: "sf2")!, UTType(filenameExtension: "dfs")!]

    var body: some View {
        ZStack {
            backgroundGradient
            identityOverlay

            VStack(spacing: 20) {
                HStack {
                    leftButton
                        .onTapGesture { toChangeNote -= 1 }

                    middleButton
                        .handleKey(.leftArrow) { toChangeNote -= direction }
                        .handleKey(.rightArrow) { toChangeNote += direction }
                        .handleKey(.space) { toToggleDrone.toggle() }
                        .onTapGesture { toToggleDrone.toggle() }

                    rightButton
                        .onTapGesture { toChangeNote += 1 }
                }

                HStack {
                    signpost.hidden()  // Hack for centering
                    sequencePicker
                    signpost
                }

                instrumentPanel
                    .colorMultiply(.drGrey8)
            }
            .padding()
            .onAppear {
                logic.loadSequence()
            }
            .onChange(of: toToggleDrone) {
                if toToggleDrone { logic.toggleDrone() }
                toToggleDrone = false
            }
            .onChange(of: toChangeNote) {
                if toChangeNote != 0 { logic.changeDrone(toChangeNote) }
                toChangeNote = 0
            }
            .onChange(of: selectedSequence) {
                logic.sequenceType = selectedSequence
                logic.loadSequence()
            }
        }
    }

    /// The "current tone" circle and keyboard event receiver
    var middleButton: some View {
        Toggle(logic.currentNoteName, isOn: $logic.isPlaying)
            .focusable()
            .focused($focused)
            .onAppear { focused = true }
            .toggleStyle(EncircledToggleStyle(
                onTextColor: .drGreen4,
                onBackColor: .drGrey8,
                offTextColor: .drGreen3,
                offBackColor: .drGrey7
            ))
    }
    
    var leftButton: some View {
        prevNextButton(text: logic.previousNoteName, cond: direction < 0)
    }
    
    var rightButton: some View {
        prevNextButton(text: logic.nextNoteName, cond: direction > 0)
    }

    /// The "previous/next tone" circles
    func prevNextButton(text: String, cond: Bool) -> some View {
        return Text(text)
            .encircle(
                diameter: 80,
                shadowRadius: cond ? 6 : 3,
                textColor: cond ? .drGreen2 : .drGreen1,
                circleColor: cond ? .drGrey7 : .drGrey6)
    }

    /// The sequence type (circle of fourths, etc.) picker
    var sequencePicker: some View {
        Picker("", selection: $selectedSequence) {
            ForEach(SequenceType.allCases) { sequence in
                Text(sequence.rawValue).tag(sequence)
            }
        }
        .pickerStyle(sequencePickerStyle)
        .colorMultiply(sequencePickerTint)
        .fixedSize()
    }

    var instrumentView: some View {
        HStack {
            Text(logic.instrument ?? "None")
                .font(.callout.monospaced())

            Button("Next Program", systemImage: "waveform") {
                logic.nextProgram()
            }
            .labelStyle(.iconOnly)
            .fixedSize()
            .disabled(logic.instrument == nil)
            .foregroundStyle(logic.instrument == nil ? Color.gray : Color.primary)
        }
    }

    var volumeSlider: some View {
        slider(value: $logic.volume, low: "speaker", high: "speaker.wave.3", help: "Volume")
    }

    var velocitySlider: some View {
        slider(value: $logic.velocity, low: "dial.low", high: "dial.high", help: "MIDI Velocity")
            .disabled(logic.instrument == nil)
    }

    var stringsButton: some View {
        Button(Instrument.strings.rawValue) {
            logic.loadInstrument()
        }
    }

    var beepButton: some View {
        Button(Instrument.beep.rawValue) {
            logic.resetInstrument()
        }
    }

    /// Slider with label showing (on iOS it doesn't)
    func slider(value: Binding<Double>, low: String, high: String, help: String) -> some View {
        return HStack {
            Label("", systemImage: low).foregroundStyle(Color(.drGreen2))
            Slider(value: value, in: 0...1) { EmptyView() }
            Label("", systemImage: high).foregroundStyle(Color(.drGreen2))
        }.padding(.horizontal)
    }

    /// The "which way" button
    var signpost: some View {
        Image(systemName: direction > 0 ? "signpost.right.fill" : "signpost.left.fill")
            .encircle(diameter: 44,
                      textColor: .drGreen3,
                      circleColor: .drGrey8,
                      textFont: .body)
            .onTapGesture { direction = -direction }
    }

    /// The background color
    var backgroundGradient: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .drPurple8, location: 0.7),
                Gradient.Stop(color: .drPurple9, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }

    /// Shows the app name and version in the background
    var identityOverlay: some View {
        VStack {
            Spacer()
            Label(getWhoAmI(), systemImage: "")
                .font(.caption)
        }
        .padding()
        .opacity(0.7)
    }

#if os(macOS)
    private let sequencePickerStyle = SegmentedPickerStyle()
    private let sequencePickerTint = Color.drGrey8

    func pickSoundFont() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = soundbankTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            return panel.url!
        }
        return nil
    }

    var soundbankButton: some View {
        Button("Load Soundbank...") {
            if let url = pickSoundFont() {
                logic.loadInstrument(url)
            }
        }
    }

    var instrumentPanel: some View {
        VStack {
            HStack {
                soundbankButton
                stringsButton
                beepButton
                instrumentView
            }
            volumeSlider
            velocitySlider
        }
    }
#else
    @State private var soundbankUrl: URL?
    @State private var isSoundbankPickerPresented = false
    @State private var isAudioSheetPresented = false
    private let sequencePickerStyle = DefaultPickerStyle()
    private let sequencePickerTint = Color.drGreen2

    var instrumentPanel: some View {
        Button("Audio", systemImage: "gearshape") {
            isAudioSheetPresented = true
        }
        .foregroundStyle(Color.drGrey2)
        .sheet(isPresented: $isAudioSheetPresented) {
            VStack(spacing: 20) {
                HStack {
                    soundbankButton
                    stringsButton
                    beepButton
                }
                .buttonStyle(.bordered)
                instrumentView
                volumeSlider
                velocitySlider
                Button("Close", systemImage: "xmark.circle") {
                    isAudioSheetPresented = false
                }
            }
        }
        .foregroundStyle(Color.primary)
    }

    var soundbankButton: some View {
        Button("Load...") {
            isSoundbankPickerPresented = true
        }
        .sheet(isPresented: $isSoundbankPickerPresented) {
            FilePickerIOS(fileURL: $soundbankUrl, types: soundbankTypes)
        }
        .onChange(of: isSoundbankPickerPresented) {
            if !isSoundbankPickerPresented {
                if let url = soundbankUrl {
                    logic.loadInstrument(url)
                }
            }
        }
    }
#endif
}
