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
    @AppStorage("sequence") private var selectedSequence: SequenceType = .circleOfFourth
    /// How much to add to the current note index when the right arrow key is pressed ("forward")
    @AppStorage("direction") private var direction = 1
    @AppStorage("volume") var volume: Double = 1.0
    @AppStorage("velocity") var velocity: Double = 0.8
    // Since calling `audioManager` from `.onKeyPress` issues errors, save them aside
    @State private var toChangeNote = 0
    // Since calling `audioManager` from `.onTap` issues errors, save them aside
    @State private var toToggleDrone = false
    @FocusState private var haveKeyboardFocus: Bool
    private let soundbankTypes = [UTType(filenameExtension: "sf2")!, UTType(filenameExtension: "dfs")!]
    private let MAIN_TOUR = ["middle", "right", "sequence", "signpost"]
    private let AUDIO_TOUR = ["soundbank", "program", "velocity"]
    private let SOUNDBANK_TOUR_TEXT = "Choose a soundbank file."
    private var tour: Tour
    private var audioTour: Tour

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
                        .addToTour(tour, "middle", "Current note.\nTap to start/stop drone.")

                    rightButton
                        .onTapGesture { toChangeNote += 1 }
                        .addToTour(tour, "right", "Next note.\nTap to change to this note.")
                }

                HStack {
                    signpost.hidden()  // Hack for centering
                    sequencePicker
                        .addToTour(tour, "sequence", "Sequence of drone notes.")
                    signpost
                        .addToTour(tour, "signpost", "Direction for 'next'\n(using foot pedal or ▶)")
                }

                instrumentPanel
                    .colorMultiply(.drGrey8)
            }
            .padding()
            .onAppear {
                loadSequence()
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
                loadSequence()
            }
        }
    }

    private func loadSequence() {
        logic.sequenceType = selectedSequence
        logic.loadSequence()
    }

    /// The "current tone" circle and keyboard event receiver
    var middleButton: some View {
        Toggle(logic.currentNoteName, isOn: $logic.isPlaying)
            .focusable()
            .focused($haveKeyboardFocus)
            .onAppear { haveKeyboardFocus = true }
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
            .addToTour(audioTour, "program", "Next program within soundbank")
        }
    }

    var volumeSlider: some View {
        slider(value: $volume, low: "speaker", high: "speaker.wave.3", help: "Volume", propagate: { logic.setVolume(volume) })
    }

    var velocitySlider: some View {
        slider(value: $velocity, low: "dial.low", high: "dial.high", help: "MIDI Velocity", propagate: { logic.setVelocity(velocity) })
            .disabled(logic.instrument == nil)
            .addToTour(audioTour, "velocity", "MIDI velocity")
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

    var tourButton: some View {
        Button("", systemImage: tour.inProgress ? "xmark.circle" : "questionmark.circle") { tour.toggle() }
        .fixedSize()
    }

    /// Slider with label showing (on iOS it doesn't)
    func slider(value: Binding<Double>, low: String, high: String, help: String, propagate: @escaping () -> Void) -> some View {
        return HStack {
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
        .onAppear() { propagate() }
    }
    
    func sliderLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage).labelStyle(.iconOnly)//.foregroundStyle(Color(.drGreen2))
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
            HStack() {
                tourButton.hidden()
                Spacer()
                Link(getWhoAmI(), destination: URL(string: "https://github.com/ErezVolk/Droneroo")!)
                    .font(.caption)
                    .opacity(0.7)
                Spacer()
                tourButton
            }
        }
        .padding()
    }

#if os(macOS)
    private let sequencePickerStyle = SegmentedPickerStyle()
    private let sequencePickerTint = Color.drGrey8
    
    init() {
        tour = Tour(MAIN_TOUR + AUDIO_TOUR)
        audioTour = tour
    }

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
        .addToTour(audioTour, "soundbank", SOUNDBANK_TOUR_TEXT)
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
    
    init() {
        tour = Tour(MAIN_TOUR + ["audio"])
        audioTour = Tour(AUDIO_TOUR)
    }

    var instrumentPanel: some View {
        Button("Audio", systemImage: "gearshape") {
            isAudioSheetPresented = true
        }
        .foregroundStyle(Color.drGrey2)
        .addToTour(tour, "audio", "Audio options")
        .sheet(isPresented: $isAudioSheetPresented) {
            ZStack {
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
                }
                
                VStack {
                    Spacer()
                    HStack {
                        audioTourButton.hidden()
                        Spacer()
                        Button("Close", systemImage: "xmark.circle") {
                            isAudioSheetPresented = false
                        }
                        Spacer()
                        audioTourButton
                    }
                    .padding()
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
        .addToTour(audioTour, "soundbank", SOUNDBANK_TOUR_TEXT)
        .onChange(of: isSoundbankPickerPresented) {
            if !isSoundbankPickerPresented {
                if let url = soundbankUrl {
                    logic.loadInstrument(url)
                }
            }
        }
    }

    var audioTourButton: some View {
        Button("Tour", systemImage: audioTour.inProgress ? "xmark.circle" : "questionmark.circle") {
            audioTour.toggle()
        }
        .labelStyle(.iconOnly)
        .fixedSize()
    }
#endif
}
