// Created by Erez Volk.

import SwiftUI
import Combine

/// TODO: Redo MIDI instrument controls
/// TODO: Control click volume/velocity
struct DronerooView: View {
    @StateObject private var logic = DronerooLogic()
    
    @AppStorage("series") private var selectedSeries: SeriesType = .circleOfFourth
    
    /// How much to add to the current note index when the right arrow key is pressed ("forward")
    @AppStorage("direction") private var direction = 1
    @AppStorage("volume") var volume = 1.0
    @AppStorage("velocity") var velocity = 0.8
    @AppStorage("soundbank") var soundbank: URL?
    @AppStorage("program") var program = 0
    @AppStorage("index") var index = 0
    @AppStorage("bpm") var bpm = 60.00
    @AppStorage("linked") var isLinked = true

    // Since calling `logic` from `.onKeyPress`/`.onTap` issues errors, save them aside
    @State private var pendingDroneChange = 0

    @State var isDroning = false
    @State var isTicking = false
    @State var currentNote = "?"
    @State var previousNote = "?"
    @State var nextNote = "?"
    @State var pivotNote = "?"
    @FocusState private var haveKeyboardFocus: Bool
    
    private let mainTourStops = ["middle", "right", "series", "signpost"]
    private let audioTourStops = ["soundbank", "program", "velocity"]
    private let postAudioTourStops = ["reset"]
    private let soundBankTourText = "Choose a soundbank file"
    private var tour: Tour
    private var audioTour: Tour

    var body: some View {
        ZStack {
            backgroundGradient
            identityOverlay

            VStack(spacing: 20) {
                
                VStack(spacing: 10) { // Smaller spacing between drone and metronome controls
                    HStack {
                        leftButton
                            .onTapGesture { pendingDroneChange -= 1 }
                        
                        middleButton
                            .handleKey(.leftArrow) { pendingDroneChange -= direction }
                            .handleKey(.rightArrow) { pendingDroneChange += direction }
                            .handleKey(.space) { isDroning.toggle() }
                            .onTapGesture { isDroning.toggle() }
                            .addToTour(tour, "middle", "Current note.\nTap to start/stop drone.")
                        
                        rightButton
                            .onTapGesture { pendingDroneChange += 1 }
                            .addToTour(tour, "right", "Next note.\nTap to change to this note.")
                    }
                    
                    linkedButton
                    
                    BpmControlView(bpm: $bpm, isOn: $isTicking)
                }
                
                HStack {
                    signpost.hidden()  // Hack for centering
                    seriesPicker
                        .addToTour(tour, "series", "Series of drone notes.")
                    signpost
                        .addToTour(tour, "signpost", "Direction for 'next'\n(using foot pedal or ▶)")
                }
                
                instrumentPanel
                    .colorMultiply(.drGrey8)
            }
            .padding()
            .onAppear { reapplySavedState() }
            .onChange(of: selectedSeries) { loadSeries() }
            .onChange(of: bpm) { logic.setBpm(bpm) }
            .onChange(of: isDroning) {
                updateState(newDroning: isDroning, newTicking: isLinked ? isDroning : isTicking)
            }
            .onChange(of: isTicking) {
                updateState(newDroning: isLinked ? isTicking : isDroning, newTicking: isTicking)
            }
            .onChange(of: isLinked) {
                guard isLinked && (isDroning || isTicking) else { return }
                updateState(newDroning: true, newTicking: true)
            }
            .onChange(of: pendingDroneChange) {
                if pendingDroneChange != 0 { updatePosition(logic.changeDrone(pendingDroneChange)) }
                pendingDroneChange = 0
            }
        }
    }

    private func reapplySavedState() {
        direction = direction < 0 ? -1 : 1
        volume = max(0, min(volume, 1.0))
        velocity = max(0, min(velocity, 1.0))
        if let soundbank {
            updateSounder(logic.loadInstrument(soundbank, program: program))
        } else {
            updateSounder(logic.loadBeep())
        }
        loadSeries(index)
        logic.setBpm(bpm)
    }
    
    private func updateState(newDroning: Bool, newTicking: Bool) -> Void {
        isDroning = newDroning
        isTicking = newTicking
        logic.setIsTicking(isTicking)
        logic.setIsDroning(isDroning)
    }

    private func loadSeries(_ index: Int? = nil) {
        updatePosition(logic.loadSeries(selectedSeries, index))
    }

    private func updatePosition(_ position: Position) {
        index = position.index
        pivotNote = position.pivotNote
        currentNote = position.currentNote
        previousNote = position.previousNote
        nextNote = position.nextNote
    }
    
    /// The "drone and metronome link" button
    var linkedButton: some View {
        Button("Linked", systemImage: isLinked ? "lock" : "lock.open") { isLinked.toggle() }
            .imageScale(.large)
            .plainButton()
    }

    /// The "current tone" circle and keyboard event receiver
    var middleButton: some View {
        Toggle(currentNote, isOn: $isDroning)
            .focusable()
            .focused($haveKeyboardFocus)
            .onAppear { haveKeyboardFocus = true }
            .toggleStyle(EncircledToggleStyle(
                bold: pivotNote == currentNote,
                onTextColor: .drGreen4,
                onBackColor: .drGrey8,
                offTextColor: .drGreen3,
                offBackColor: .drGrey7
            ))
    }

    var leftButton: some View {
        prevNextButton(text: previousNote, pending: direction < 0)
    }

    var rightButton: some View {
        prevNextButton(text: nextNote, pending: direction > 0)
    }

    /// The "previous/next tone" circles
    func prevNextButton(text: String, pending: Bool) -> some View {
        return Text(text)
            .encircle(
                diameter: 80,
                shadowRadius: pending ? 6 : 3,
                textColor: pending ? .drGreen2 : .drGreen1,
                circleColor: pending ? .drGrey7 : .drGrey6,
                bold: pivotNote == text)
    }

    /// The series type (circle of fourths, etc.) picker
    var seriesPicker: some View {
        Picker("", selection: $selectedSeries) {
            ForEach(SeriesType.allCases) { series in
                Text(series.rawValue).tag(series)
            }
        }
        .pickerStyle(seriesPickerStyle)
        .colorMultiply(seriesPickerTint)
        .fixedSize()
    }

    var instrumentView: some View {
        HStack {
            Text(soundbank == nil ? "None": "\(soundbank!.deletingPathExtension().lastPathComponent):\(program)")
                .font(.callout.monospaced())

            Button("Next progream", systemImage: "waveform") {
                nextProgram()
            }
            .plainButton()
            .disabled(soundbank == nil)
            .foregroundStyle(soundbank == nil ? Color.gray : Color.primary)
            .addToTour(audioTour, "program", "Next program within soundbank")
        }
    }

    func nextProgram() {
        if let soundbank {
            self.updateSounder(logic.loadInstrument(soundbank, program: program + 1) ?? logic.loadInstrument(soundbank))
        }
    }

    func updateSounder(_ sounder: Sounder?) {
        if let sounder {
            soundbank = sounder.soundbank
            program = sounder.program
        } else {
            soundbank = nil
            program = 0
        }
    }

    var volumeSlider: some View {
        LabeledSlider(value: $volume, low: "speaker", high: "speaker.wave.3", help: "Volume") {
            logic.setVolume(volume)
        }
    }

    var velocitySlider: some View {
        LabeledSlider(value: $velocity,
                      low: "gauge.open.with.lines.needle.33percent.and.arrowtriangle",
                      high: "gauge.open.with.lines.needle.67percent.and.arrowtriangle",
                      help: "MIDI Velocity",
                      propagate: { logic.setVolume(velocity) })
        .disabled(soundbank == nil)
        .addToTour(audioTour, "velocity", "MIDI velocity")
    }

    var stringsButton: some View {
        Button(Instrument.strings.rawValue) {
            updateSounder(logic.loadDefaultInstrument())
        }
    }

    var beepButton: some View {
        Button(Instrument.beep.rawValue) {
            updateSounder(logic.loadBeep())
        }
    }

    var resetButton: some View {
        Button("Reset", systemImage: "arrow.uturn.backward.circle") {
            DronerooState.shared.reset()
        }
        .plainButton()
        .addToTour(tour, "reset", "Reset state")
    }

    var tourButton: some View {
        Button("Tour", systemImage: tour.inProgress ? "xmark.circle" : "questionmark.circle") {
            tour.toggle()
        }.plainButton()
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
        .onTapGesture {
            tour.stopTheTour()
            audioTour.stopTheTour()
        }
    }

    /// Shows the app name and version in the background
    var identityOverlay: some View {
        VStack {
            Spacer()
            ZStack {
                InfoView()
                HStack {
                    resetButton
                    Spacer()
                }
                HStack {
                    Spacer()
                    tourButton
                }
            }
        }
        .padding()
    }

#if os(macOS)
    private let seriesPickerStyle = SegmentedPickerStyle()
    private let seriesPickerTint = Color.drGrey8

    init() {
        tour = Tour(mainTourStops + audioTourStops + postAudioTourStops)
        audioTour = tour
    }

    func pickSoundFont() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = DronerooLogic.soundbankTypes
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
                updateSounder(logic.loadInstrument(url))
            }
        }
        .addToTour(audioTour, "soundbank", soundBankTourText)
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
    @State private var isSoundbankPickerPresented = false
    @State private var isAudioSheetPresented = false
    private let seriesPickerStyle = DefaultPickerStyle()
    private let seriesPickerTint = Color.drGreen2

    init() {
        tour = Tour(mainTourStops + ["audio"] + postAudioTourStops)
        audioTour = Tour(audioTourStops)
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
            FilePickerIOS(fileURL: $soundbank, types: DronerooLogic.soundbankTypes)
        }
        .addToTour(audioTour, "soundbank", soundBankTourText)
        .onChange(of: isSoundbankPickerPresented) {
            if !isSoundbankPickerPresented {
                if let url = soundbank {
                    updateSounder(logic.loadInstrument(url))
                }
            }
        }
    }

    var audioTourButton: some View {
        Button("Tour", systemImage: audioTour.inProgress ? "xmark.circle" : "questionmark.circle") {
            audioTour.toggle()
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .fixedSize()
    }
#endif
}
