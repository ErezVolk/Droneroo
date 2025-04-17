// Created by Erez Volk.

import Foundation
import AudioKit
import AVFoundation
import SwiftUI
import Combine

enum SequenceType: String, CaseIterable, Identifiable {
    case circleOfFourth = "Circle of Fourths"
    case rayBrown = "Flats, then Sharps"
    case chromatic = "Chromatic"
    var id: String { self.rawValue }
}

/// Identifier for a sound sample in a soundbank
struct Sounder {
    let soundbank: URL
    let program: Int
}

/// Current position in the sequence
struct Position {
    let index: Int
    let pivotNote: String
    let previousNote: String
    let currentNote: String
    let nextNote: String
}

class DronerooLogic: NSObject, ObservableObject {
    static let soundbankTypes = [UTType(filenameExtension: "sf2")!, UTType(filenameExtension: "dls")!]

    @Published var isPlaying = false
    private var position: Position = Position(index: 0, pivotNote: "N/A", previousNote: "?", currentNote: "?", nextNote: "?")
    private var velocity: Double = 0.8

    private let engine = AudioEngine()
    private var droneSampler = MIDISampler()
    private var clickSampler = MIDISampler()
    private let clickSequencer = AppleSequencer()
    private var mixer = Mixer()

    private var noteSequence: [UInt8] = []
    private var nameSequence: [String] = []
    private var currentIndex = 0
    private var pivotIndex: Int?
    private var currentNote: UInt8!
    private var cancellables = Set<AnyCancellable>()
    
    private let systemDLS = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    private let caffeine = Caffeine()

    override init() {
        super.init()
        setupAudioEngine()
        _ = loadSequence(.circleOfFourth)
    }

    private func setupAudioEngine() {
        do {
            let path = systemDLS.deletingPathExtension().path
            try clickSampler.loadPercussiveSoundFont(path, preset: 0)
            
            let track = clickSequencer.newTrack()
            track?.setMIDIOutput(clickSampler.midiIn)

            for idx in 0..<4 {
                let beat = Double(idx)
                track?.add(noteNumber: 56, // Cowbell (or try 76 = Hi Q)
                           velocity: 127,
                           position: Duration(beats: beat),
                           duration: Duration(beats: 0.1))
            }

            clickSequencer.setTempo(60)
            clickSequencer.enableLooping(Duration(beats: 4))
            clickSequencer.preroll()

            mixer.addInput(clickSampler)
        } catch {
            print("Error loading click sound: \(error)")
        }

        mixer.addInput(droneSampler)
        engine.output = mixer

        do {
            try engine.start()
        } catch {
            print("Audio Engine couldn't start: \(error.localizedDescription)")
        }
    }

    /// Create a new receive thingy
    func listen<T>(to published: Published<T>.Publisher, action: @escaping () -> Void) {
        published
            .receive(on: RunLoop.main)
            .sink { _ in
                action()
            }
            .store(in: &cancellables)
    }

    func setVolume(_ volume: Double) {
        mixer.volume = AUValue(volume)
    }

    func setVelocity(_ velocity: Double) {
        blink { self.velocity = velocity }
    }

    /// Reset to the default Beep sound
    func loadBeep() -> Sounder? {
        blink { _ = newSampler() }
        return nil
    }

    /// Recreate sampler object, resetting to beep
    private func newSampler() -> Sounder? {
        assert(!isPlaying)
        mixer.removeInput(droneSampler)
        droneSampler = MIDISampler()
        mixer.addInput(droneSampler)
        return nil
    }

    /// Load the bundled instrument
    func loadDefaultInstrument() -> Sounder? {
        return loadInstrument(systemDLS, program: 48)
    }

    /// Load instrument from a soundbank
    func loadInstrument(_ url: URL, program: Int = 0) -> Sounder? {
        var sounder: Sounder?
        blink {
            sounder = doLoadInstrument(soundbank: url, program: program) ?? newSampler()
        }
        return sounder
    }

    /// Actually try to load a soundbank instrument (call when not playing)
    /// On success, sets `self.soundbank` etc.
    /// On failure, leaves them untouched (caller deals with it)
    private func doLoadInstrument(soundbank: URL, program: Int) -> Sounder? {
        do {
            let path = soundbank.deletingPathExtension().path
            try droneSampler.loadSoundFont(path, preset: program, bank: 0)

            // Loading a new instrument can disable sound, so flip off and on after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.blink() }
            return Sounder(soundbank: soundbank, program: program)
        } catch {
            print("Couldn't load instrument: \(error.localizedDescription)")
            return nil
        }
    }

    /// Start playing.
    private func startDrone(setPivot: Bool = false) {
        guard !isPlaying else { return }
        if setPivot {
            pivotIndex = currentIndex
            setPosition(currentIndex)
        }
        let velocity = UInt8(self.velocity * 127)
        droneSampler.play(noteNumber: MIDINoteNumber(currentNote), velocity: velocity, channel: 0)
        droneSampler.play(noteNumber: MIDINoteNumber(currentNote + 12), velocity: velocity, channel: 0)
        setIsPlaying(true)
    }

    /// Stop playing.
    private func stopDrone(clearPivot: Bool = false) {
        guard isPlaying else { return }
        droneSampler.stop(noteNumber: MIDINoteNumber(currentNote), channel: 0)
        droneSampler.stop(noteNumber: MIDINoteNumber(currentNote + 12), channel: 0)
        setIsPlaying(false)
        if clearPivot {
            pivotIndex = nil
            setPosition(currentIndex)
        }
    }

    /// Set current note for playback and display (and profit).
    private func setPosition(_ index: Int) {
        assert(!isPlaying)
        currentIndex = modSeq(index)
        currentNote = noteSequence[index]
        position = Position(
            index: index,
            pivotNote: pivotIndex != nil ? nameSequence[pivotIndex!] : "N/A",
            previousNote: nameSequence[modSeq(index - 1)],
            currentNote: nameSequence[index],
            nextNote: nameSequence[modSeq(index + 1)])
    }

    /// Set the `isPlaying` flag, and also try to disable screen sleeping
    private func setIsPlaying(_ newValue: Bool) {
        guard newValue != isPlaying else { return }
        isPlaying = newValue
        caffeine.stayUp(newValue)
    }

    /// Pause/Play.
    /// This is the user command, and shouldn't be called internally.
    func toggleDrone() -> Position {
        if isPlaying {
            stopDrone(clearPivot: true)
            clickSequencer.stop()
        } else {
            startDrone(setPivot: true)
            clickSequencer.rewind()
            clickSequencer.play()
        }
        return position
    }

    /// Update the current note, based on `delta` and `sequenceOrder`
    func changeDrone(_ delta: Int) -> Position {
        blink { setPosition(modSeq(currentIndex + delta)) }
        return position
    }

    /// Set specific drone by index in current sequence
    func setDrone(_ index: Int) -> Position {
        blink { setPosition(modSeq(index)) }
        return position
    }
    
    func setBpm(_ bpm: Int) -> Void {
        clickSequencer.setTempo(Double(bpm))
    }
    
    func setClickOn(_ clickOn: Bool) -> Void {
        print("EREZ EREZ IMPLEMENT ME")
    }

    /// Do `action` while not playing (pause and resume if called while playing)
    /// When `action` is not given, this just makes sure playback stops and starts,
    /// so audio changes (instrument, velocity, etc.) take effect.
    private func blink(_ action: (_ wasPlaying: Bool) -> Void = {_ in ()}) {
        let wasPlaying = isPlaying
        if wasPlaying { stopDrone() }
        action(wasPlaying)
        if wasPlaying { startDrone() }
    }

    /// Do `action` while not playing (pause and resume if called while playing)
    /// A version of `blink()` that doesn't care about `wasPlaying`.
    private func blink(_ action: () -> Void) {
        blink { _ in action() }
    }

    /// Configure the actual sequence of notes, based on `sequenceType`.
    func loadSequence(_ sequenceType: SequenceType, _ index: Int? = nil) -> Position {
        blink {
            switch sequenceType {
            case .circleOfFourth:
                nameSequence = ["C", "F", "A♯/B♭", "D♯/E♭", "G♯/A♭", "C♯/D♭", "F♯/G♭", "B", "E", "A", "D", "G"]
            case .rayBrown:
                nameSequence = ["C", "F", "B♭", "E♭", "A♭", "D♭", "G", "D", "A", "E", "B", "F♯"]
            case .chromatic:
                nameSequence = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]
            }
            noteSequence = nameSequence.map(DronerooLogic.noteNameToMidiNumber)
            setPosition(index ?? 0)
        }
        return position
    }

    /// "Modulu (current) Sequence"
    private func modSeq(_ index: Int) -> Int {
        var idx = index
        while idx < 0 { idx += noteSequence.count }
        return idx % noteSequence.count
    }

    /// Converts a string like "C#" to a MIDI note number in octave 2 (C2...B2)
    static func noteNameToMidiNumber(_ noteName: String) -> UInt8 {
        let match = noteName.firstMatch(of: /([a-gA-G])((𝄫|♭♭|bb)|([b♭])|(𝄪|x|##|♯♯)|([#♯]))?/)!
        let base = Array("CCDDEFFGGAAB").firstIndex(of: match.1.uppercased().first!)!
        let delta = match.3 != nil ? 10 : match.4 != nil ? 11 : match.5 != nil ? 2 : match.6 != nil ? 1 : 0
        return UInt8(48 + (base + delta) % 12)
    }

}
