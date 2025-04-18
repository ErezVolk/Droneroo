// Created by Erez Volk.

import Foundation
import AudioKit
import AVFoundation
import SwiftUI
import Combine

/// Type of series/tone row
enum SeriesType: String, CaseIterable, Identifiable {
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

/// Current position in the series
struct Position {
    let index: Int
    let pivotNote: String
    let previousNote: String
    let currentNote: String
    let nextNote: String
}

class DronerooLogic: NSObject, ObservableObject {
    static let soundbankTypes = [UTType(filenameExtension: "sf2")!, UTType(filenameExtension: "dls")!]

    private var isDroning = false
    private var isTicking = false
    
    private var position: Position = Position(index: 0, pivotNote: "N/A", previousNote: "?", currentNote: "?", nextNote: "?")
    private var velocity: Double = 0.8

    private let engine = AudioEngine()
    private var droneSampler = MIDISampler()
    private var clickSampler = MIDISampler()
    private let clickSequencer = AppleSequencer()
    private var mixer = Mixer()

    private var noteSeries: [UInt8] = []
    private var nameSeries: [String] = []
    private var currentIndex = 0
    private var pivotIndex: Int?
    private var currentNote: UInt8!
    
    private let bundledDrone = Bundle.main.url(forResource: "JR_String2", withExtension: "sf2")!
    private let bundledClick = Bundle.main.url(forResource: "Woodblocks", withExtension: "sf2")!
    private let caffeine = Caffeine()

    override init() {
        super.init()
        setupAudioEngine()
        _ = loadSeries(.circleOfFourth)
    }

    private func setupAudioEngine() {
        do {
            try clickSampler.loadSoundFont(loadablePath(bundledClick), preset: 0, bank: 0)
            
            let track = clickSequencer.newTrack()
            track?.setMIDIOutput(clickSampler.midiIn)
            
            
            track?.add(noteNumber: 78,
                       velocity: 127,
                       position: Duration(beats: 0.0),
                       duration: Duration(beats: 0.1))
            
            clickSequencer.setTempo(60)
            clickSequencer.enableLooping(Duration(beats: 1))
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
        assert(!isDroning)
        mixer.removeInput(droneSampler)
        droneSampler = MIDISampler()
        mixer.addInput(droneSampler)
        return nil
    }

    /// Load the bundled instrument
    func loadDefaultInstrument() -> Sounder? {
        return loadInstrument(bundledDrone, program: 48)
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
            try droneSampler.loadSoundFont(loadablePath(soundbank), preset: program, bank: 0)

            // Loading a new instrument can disable sound, so flip off and on after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.blink() }
            return Sounder(soundbank: soundbank, program: program)
        } catch {
            print("Couldn't load instrument: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadablePath(_ url: URL) -> String {
        return url.deletingPathExtension().path
    }
    
    func setIsDroning(_ newValue: Bool) -> Void {
        guard newValue != isDroning else { return }
        if newValue { startDrone() }
        else { stopDrone() }
    }

    func setIsTicking(_ newValue: Bool) -> Void {
        guard newValue != isTicking else { return }
        if newValue { startTicks() }
        else { stopTicks() }
    }
    
    /// Start the drone.
    private func startDrone(setPivot: Bool = false) {
        guard !isDroning else { return }
        if setPivot {
            pivotIndex = currentIndex
            setPosition(currentIndex)
        }
        let velocity = UInt8(self.velocity * 127)
        droneSampler.play(noteNumber: MIDINoteNumber(currentNote), velocity: velocity, channel: 0)
        droneSampler.play(noteNumber: MIDINoteNumber(currentNote + 12), velocity: velocity, channel: 0)
        isDroning = true
        updateCaffeine()
    }

    /// Stop the drone.
    private func stopDrone(clearPivot: Bool = false) {
        guard isDroning else { return }
        droneSampler.stop(noteNumber: MIDINoteNumber(currentNote), channel: 0)
        droneSampler.stop(noteNumber: MIDINoteNumber(currentNote + 12), channel: 0)
        isDroning = false
        setIsDroning(false)
        if clearPivot {
            pivotIndex = nil
            setPosition(currentIndex)
        }
    }
    
    private func startTicks() {
        guard !isTicking else { return }
        clickSequencer.rewind()
        clickSequencer.play()
        isTicking = true
        updateCaffeine()
    }

    private func stopTicks() {
        guard isTicking else { return }
        clickSequencer.stop()
        isTicking = false
        updateCaffeine()
    }
    
    /// Set current note for playback and display (and profit).
    private func setPosition(_ index: Int) {
        assert(!isDroning)
        currentIndex = modSeq(index)
        currentNote = noteSeries[index]
        position = Position(
            index: index,
            pivotNote: pivotIndex != nil ? nameSeries[pivotIndex!] : "N/A",
            previousNote: nameSeries[modSeq(index - 1)],
            currentNote: nameSeries[index],
            nextNote: nameSeries[modSeq(index + 1)])
    }

    /// Disable screen sleeping if we're playing something
    private func updateCaffeine() -> Void {
        caffeine.stayUp(isDroning || isTicking)
    }
    
    /// Update the current note, based on `delta` and `seriesOrder`
    func changeDrone(_ delta: Int) -> Position {
        blink { setPosition(modSeq(currentIndex + delta)) }
        return position
    }

    /// Set specific drone by index in current series
    func setDrone(_ index: Int) -> Position {
        blink { setPosition(modSeq(index)) }
        return position
    }
    
    func setBpm(_ bpm: Double) -> Void {
        clickSequencer.setTempo(bpm)
    }

    /// Do `action` while not droning (pause and resume if called while playing)
    /// When `action` is not given, this just makes sure playback stops and starts,
    /// so audio changes (instrument, velocity, etc.) take effect.
    private func blink(_ action: (_ wasPlaying: Bool) -> Void = {_ in ()}) {
        let wasDroning = isDroning
        if wasDroning { stopDrone() }
        action(wasDroning)
        if wasDroning { startDrone() }
    }

    /// Do `action` while not droning (pause and resume if called while playing)
    /// A version of `blink()` that doesn't care about `wasPlaying`.
    private func blink(_ action: () -> Void) {
        blink { _ in action() }
    }

    /// Configure the actual series of notes, based on `seriesType`.
    func loadSeries(_ seriesType: SeriesType, _ index: Int? = nil) -> Position {
        blink {
            switch seriesType {
            case .circleOfFourth:
                nameSeries = ["C", "F", "A♯/B♭", "D♯/E♭", "G♯/A♭", "C♯/D♭", "F♯/G♭", "B", "E", "A", "D", "G"]
            case .rayBrown:
                nameSeries = ["C", "F", "B♭", "E♭", "A♭", "D♭", "G", "D", "A", "E", "B", "F♯"]
            case .chromatic:
                nameSeries = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]
            }
            noteSeries = nameSeries.map(DronerooLogic.noteNameToMidiNumber)
            setPosition(index ?? 0)
        }
        return position
    }

    /// "Modulu (current) Series"
    private func modSeq(_ index: Int) -> Int {
        var idx = index
        while idx < 0 { idx += noteSeries.count }
        return idx % noteSeries.count
    }

    /// Converts a string like "C#" to a MIDI note number in octave 2 (C2...B2)
    static func noteNameToMidiNumber(_ noteName: String) -> UInt8 {
        let match = noteName.firstMatch(of: /([a-gA-G])((𝄫|♭♭|bb)|([b♭])|(𝄪|x|##|♯♯)|([#♯]))?/)!
        let base = Array("CCDDEFFGGAAB").firstIndex(of: match.1.uppercased().first!)!
        let delta = match.3 != nil ? 10 : match.4 != nil ? 11 : match.5 != nil ? 2 : match.6 != nil ? 1 : 0
        return UInt8(48 + (base + delta) % 12)
    }

}
