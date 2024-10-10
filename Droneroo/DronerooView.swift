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
    private let instrumentTypes = [UTType(filenameExtension: "sf2")!]
    
    var body: some View {
        ZStack {
            backgroundGradient
            identityOverlay
            
            VStack(spacing: 20) {
                HStack {
                    prevNextButton(text: logic.previousNoteName, cond: direction < 0)
                        .onTapGesture { toChangeNote -= 1 }
                    
                    middleButton
                        .handleKey(.leftArrow) { toChangeNote -= direction }
                        .handleKey(.rightArrow) { toChangeNote += direction }
                        .handleKey(.space) { toToggleDrone.toggle() }
                        .onTapGesture { toToggleDrone.toggle() }
                    
                    prevNextButton(text: logic.nextNoteName, cond: direction > 0)
                        .onTapGesture { toChangeNote += 1 }
                }
                
                ZStack {
                    sequencePicker
                    HStack {
                        Spacer()
                        signpost
                    }
                }
                
                instrumentPanel
                    .colorMultiply(.drGrey8)
            }
            .buttonStyle(.bordered)
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
#if os(macOS)
        .pickerStyle(.segmented)
        .colorMultiply(.drGrey8)
#else
        .colorMultiply(.drGreen2)
        .background(Color.drGrey5)
#endif
        .fixedSize()
    }
    
    /// Selection of MIDI instrument to play
    var instrumentPanel: some View {
        VStack {
            HStack {
#if os(macOS)
                Button("Load SoundFont...") {
                    if let url = pickSoundFont() {
                        logic.loadInstrument(url)
                    }
                }
#else
                Button("Load...") {
                    isSoundFontPickerPresented = true
                }
                .sheet(isPresented: $isSoundFontPickerPresented) {
                    FilePickerIOS(fileURL: $soundFontUrl, types: instrumentTypes)
                }
                .onChange(of: isSoundFontPickerPresented) {
                    if !isSoundFontPickerPresented {
                        if let url = soundFontUrl {
                            logic.loadInstrument(url)
                        }
                    }
                }
#endif
                stringsButton
                beepButton
            }
            Text(logic.instrument ?? "None")
                .monospaced()
            slider(value: $logic.volume, lo: "speaker", hi: "speaker.wave.3", help: "Volume")
            slider(value: $logic.velocity, lo: "dial.low", hi: "dial.high", help: "MIDI Velocity")
                .disabled(logic.instrument == nil)
        }
    }
    
    var stringsButton : some View {
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
    func slider(value: Binding<Double>, lo: String, hi: String, help: String) -> some View {
        return HStack {
            Label("", systemImage: lo).foregroundStyle(Color(.drGreen2))
            Slider(value: value, in: 0...1) { EmptyView() }
            Label("", systemImage: hi).foregroundStyle(Color(.drGreen2))
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
    func pickSoundFont() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = instrumentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            return panel.url!
        }
        return nil
    }
#else
    @State private var soundFontUrl: URL?
    @State private var isSoundFontPickerPresented = false
#endif
}
