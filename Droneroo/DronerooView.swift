// Created by Erez Volk.

import SwiftUI
import Combine

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
    @StateObject private var audioManager = DronerooLogic()
    @State private var selectedSequence: SequenceType = .circleOfFourth
    @FocusState private var focused: Bool
    /// How much to add to the current note index when the right arrow key is pressed ("forward")
    @State private var direction = 1
    // Since calling `audioManager` from `.onKeyPress` issues errors, save them aside
    @State private var toChangeNote = 0
    // Since calling `audioManager` from `.onTap` issues errors, save them aside
    @State private var toToggleDrone = false
#if os(iOS)
    @State private var instrument: Instrument = .beep
#endif

    var body: some View {
        ZStack {
            backgroundGradient
            identityOverlay

            VStack(spacing: 20) {
                HStack {
                    prevNextButton(text: audioManager.previousNoteName, cond: direction < 0)
                        .onTapGesture { toChangeNote -= 1 }

                    middleButton
                        .handleKey(.leftArrow) { toChangeNote -= direction }
                        .handleKey(.rightArrow) { toChangeNote += direction }
                        .handleKey(.space) { toToggleDrone.toggle() }
                        .onTapGesture { toToggleDrone.toggle() }

                    prevNextButton(text: audioManager.nextNoteName, cond: direction > 0)
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
            .padding()
            .onAppear {
                audioManager.loadSequence()
            }
            .onChange(of: toToggleDrone) {
                if toToggleDrone { audioManager.toggleDrone() }
                toToggleDrone = false
            }
            .onChange(of: toChangeNote) {
                if toChangeNote != 0 { audioManager.changeDrone(toChangeNote) }
                toChangeNote = 0
            }
            .onChange(of: selectedSequence) {
                audioManager.sequenceType = selectedSequence
                audioManager.loadSequence()
            }
        }
    }

    /// The "current tone" circle and keyboard event receiver
    var middleButton: some View {
        Toggle(audioManager.currentNoteName, isOn: $audioManager.isPlaying)
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
#if os(macOS)
            HStack {
                Button("Load SoundFont...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        audioManager.loadInstrument(panel.url!)
                    }
                }
                Button(Instrument.strings.rawValue) {
                    audioManager.loadInstrument()
                }
                Button(Instrument.beep.rawValue) {
                    audioManager.resetInstrument()
                }

                Text(audioManager.instrument)
                    .monospaced()
            }
#else
            Picker("Instrument", selection: $instrument) {
                ForEach(Instrument.allCases) { instrument in
                    Text(instrument.rawValue).tag(instrument)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: instrument) {
                switch instrument {
                case .strings: audioManager.loadInstrument()
                case .beep: audioManager.resetInstrument()
                }
            }
#endif
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
}
