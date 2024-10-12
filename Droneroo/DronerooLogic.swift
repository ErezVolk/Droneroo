// Created by Erez Volk.

import Foundation
import AVFoundation
import SwiftUI
import Combine

enum SequenceType: String, CaseIterable, Identifiable {
    case circleOfFourth = "Circle of Fourths"
    case rayBrown = "Flats, then Sharps"
    case chromatic = "Chromatic"
    var id: String { self.rawValue }
}

class DronerooLogic: NSObject, ObservableObject {
    @Published var currentNoteName: String = "None"
    @Published var previousNoteName: String = "N/A"
    @Published var nextNoteName: String = "N/A"
    @Published var volume: Double = 1.0
    @Published var velocity: Double = 0.8
    @Published var instrument: String?
    @Published var isPlaying = false
    @Published var isReversed = false
    @Published var sequenceType: SequenceType = .circleOfFourth
    private let audioEngine = AVAudioEngine()
    private var sampler = AVAudioUnitSampler()
    private var soundbank: URL?
    private var program: UInt8 = 0
    private var noteSequence: [UInt8] = []
    private var nameSequence: [String] = []
    private var currentIndex = 0
    private var currentNote: UInt8!
    private var cancellables = Set<AnyCancellable>()
    // From http://johannes.roussel.free.fr/music/soundfonts.htm
    private let defaultInstrument = Bundle.main.url(forResource: "JR_String2", withExtension: "sf2")!
    private let caffeine = Caffeine()

    override init() {
        super.init()
        setupAudioEngine()
        loadSequence()
        setCurrentNote()
    }

    private func setupAudioEngine() {
        connectSampler()
        applyVolume()

        listen(to: $volume) { self.applyVolume() }
        listen(to: $velocity) { self.applyVelocity() }

        do {
            try audioEngine.start()
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

    func applyVolume() {
        audioEngine.mainMixerNode.outputVolume = Float(volume)
    }

    func applyVelocity() {
        guard instrument != nil else { return }
        blink() // Restarting the sound will play with the new velocity
    }

    /// Reset to the default Beep sound
    func resetInstrument() {
        blink { newSampler() }
    }

    /// Recreate sample, resetting to beep
    private func newSampler() {
        assert(!isPlaying)
        audioEngine.detach(sampler)
        sampler = AVAudioUnitSampler()
        instrument = nil
        soundbank = nil
        connectSampler()
    }

    private func connectSampler() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
    }

    /// Load a SoundFont file
    func loadInstrument(_ url: URL? = nil) {
        blink {
            if !doLoadInstrument(soundbank: url ?? defaultInstrument, program: 0) {
                newSampler()
            }
        }
    }

    /// Within the current soundbank, try to load the next program
    func nextProgram() {
        guard let soundbank else { return }
        blink {
            if !doLoadInstrument(soundbank: soundbank, program: program + 1) {
                if !doLoadInstrument(soundbank: soundbank, program: 0) {
                    newSampler()
                }
            }
        }
    }

    /// Actually try to load a soundbank instrument (call when not playing)
    /// On success, sets `self.soundbank` etc.
    /// On failure, leaves them untouched (caller deals with it)
    private func doLoadInstrument(soundbank: URL, program: UInt8) -> Bool {
        do {
            try sampler.loadSoundBankInstrument(
                at: soundbank,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB))

            self.soundbank = soundbank
            self.program = program
            self.instrument = "\(soundbank.deletingPathExtension().lastPathComponent):\(program)"

            // Loading a new instrument can disable sound, so flip off and on after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.blink() }
            return true
        } catch {
            print("Couldn't load instrument: \(error.localizedDescription)")
            return false
        }
    }

    /// Start playing.
    private func startDrone() {
        guard !isPlaying else { return }
        setCurrentNote() // Probably redundant, but can't hurt
        let velocity = UInt8(self.velocity * 127)
        sampler.startNote(currentNote, withVelocity: velocity, onChannel: 0)
        sampler.startNote(currentNote + 12, withVelocity: velocity, onChannel: 0)
        setIsPlaying(true)
    }

    /// Stop playing.
    private func stopDrone() {
        guard isPlaying else { return }
        sampler.stopNote(currentNote, onChannel: 0)
        sampler.stopNote(currentNote + 12, onChannel: 0)
        setIsPlaying(false)
    }

    /// Set current note for playback and display (and profit).
    private func setCurrentNote() {
        assert(!isPlaying)
        currentNote = noteSequence[currentIndex]
        currentNoteName = nameSequence[currentIndex]
        previousNoteName = nameSequence[(currentIndex + nameSequence.count - 1) % nameSequence.count]
        nextNoteName = nameSequence[(currentIndex + 1) % nameSequence.count]
    }

    /// Set the `isPlaying` flag, and also try to disable screen sleeping
    private func setIsPlaying(_ newValue: Bool) {
        if newValue == isPlaying { return }
        isPlaying = newValue
        caffeine.stayUp(newValue)
    }

    /// Pause/Play.
    func toggleDrone() {
        if isPlaying {
            stopDrone()
        } else {
            startDrone()
        }
    }

    /// Update the current note, based on `delta` and `sequenceOrder`
    func changeDrone(_ delta: Int) {
        let mod = noteSequence.count
        blink {
            currentIndex = (((currentIndex + delta) % mod) + mod) % mod
            setCurrentNote()
        }
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
        blink { _ in
            action()
        }
    }

    /// Configure the actual sequence of notes, based on `sequenceType`.
    func loadSequence() {
        blink {
            currentIndex = 0
            switch sequenceType {
            case .circleOfFourth:
                nameSequence = ["C", "F", "A♯/B♭", "D♯/E♭", "G♯/A♭", "C♯/D♭", "F♯/G♭", "B", "E", "A", "D", "G"]
            case .rayBrown:
                nameSequence = ["C", "F", "B♭", "E♭", "A♭", "D♭", "G", "D", "A", "E", "B", "F♯"]
            case .chromatic:
                nameSequence = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]
            }
            noteSequence = nameSequence.map { DronerooLogic.noteNameToMidiNumber($0) }
            setCurrentNote()
        }
    }

    /// Converts a string like "C#" to a MIDI note number in octave 2 (C2...B2)
    static func noteNameToMidiNumber(_ noteName: String) -> UInt8 {
        let match = noteName.firstMatch(of: /([a-gA-G])((𝄫|♭♭|bb)|([b♭])|(𝄪|x|##|♯♯)|([#♯]))?/)!
        let base = Array("CCDDEFFGGAAB").firstIndex(of: match.1.uppercased().first!)!
        let delta = match.3 != nil ? 10 : match.4 != nil ? 11 : match.5 != nil ? 2 : match.6 != nil ? 1 : 0
        return UInt8(48 + (base + delta) % 12)
    }
}
