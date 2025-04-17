// Created by Erez Volk.

import SwiftUI
import Combine

struct BmpControlView: View {
    @Binding var bpm: Double
    @Binding var isOn: Bool
    @State var knobAngleDeg: CGFloat = 0.0
    private let minBpm: Double = 30
    private let maxBpm: Double = 300
    private let diameter: Int = 100
    private let knobRadius: CGFloat = 6
    
    var body: some View {
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
                                change(location: value.location)
                            }))
        }
        .onAppear {
            placeKnob()
        }
    }
    
    private func placeKnob() {
        let fixedAngleRad = (bpm - minBpm) / (maxBpm - minBpm) * (2.0 * .pi)
        knobAngleDeg = fixedAngleRad * 180 / .pi
    }
    
    private func change(location: CGPoint) {
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

struct DronerooView: View {
    @StateObject private var logic = DronerooLogic()
    @AppStorage("sequence") private var selectedSequence: SequenceType = .circleOfFourth
    /// How much to add to the current note index when the right arrow key is pressed ("forward")
    @AppStorage("direction") private var direction = 1
    @AppStorage("volume") var volume: Double = 1.0
    @AppStorage("velocity") var velocity: Double = 0.8
    @AppStorage("soundbank") var soundbank: URL?
    @AppStorage("program") var program: Int = 0
    @AppStorage("index") var index: Int = 0
    @AppStorage("click") var isClicking: Bool = true
    @AppStorage("bpm") var bpm: Double = 60
    @AppStorage("both") var both: Bool = true

    // Since calling `logic` from `.onKeyPress`/`.onTap` issues errors, save them aside
    @State private var toChangeNote = 0
    @State private var toToggleDrone = false

    @State var currentNote: String = "?"
    @State var previousNote: String = "?"
    @State var nextNote: String = "?"
    @State var pivotNote: String = "?"
    @FocusState private var haveKeyboardFocus: Bool
    private let mainTourStops = ["middle", "right", "sequence", "signpost"]
    private let audioTourStops = ["soundbank", "program", "velocity"]
    private let postAudioTourStops = ["reset"]
    private let soundBankTourText = "Choose a soundbank file."
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
                
                Button("Both", systemImage: both ? "lock" : "lock.open") { both.toggle() }
                    .plainButton()
                
                BmpControlView(bpm: $bpm, isOn: $isClicking)
                
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
            .onAppear { reapplySavedState() }
            .onChange(of: selectedSequence) { loadSequence() }
            .onChange(of: isClicking) { logic.setClickOn(isClicking) }
            .onChange(of: bpm) { logic.setBpm(bpm) }
            .onChange(of: toToggleDrone) {
                if toToggleDrone { updatePosition(logic.toggleDrone()) }
                toToggleDrone = false
            }
            .onChange(of: toChangeNote) {
                if toChangeNote != 0 { updatePosition(logic.changeDrone(toChangeNote)) }
                toChangeNote = 0
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
        loadSequence(index)
        logic.setBpm(bpm)
        logic.setClickOn(isClicking)
    }

    private func loadSequence(_ index: Int? = nil) {
        updatePosition(logic.loadSequence(selectedSequence, index))
    }

    private func updatePosition(_ position: Position) {
        index = position.index
        pivotNote = position.pivotNote
        currentNote = position.currentNote
        previousNote = position.previousNote
        nextNote = position.nextNote
    }

    /// The "current tone" circle and keyboard event receiver
    var middleButton: some View {
        Toggle(currentNote, isOn: $logic.isPlaying)
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
    private let sequencePickerStyle = SegmentedPickerStyle()
    private let sequencePickerTint = Color.drGrey8

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
    private let sequencePickerStyle = DefaultPickerStyle()
    private let sequencePickerTint = Color.drGreen2

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
