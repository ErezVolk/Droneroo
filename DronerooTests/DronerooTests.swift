//  Created by Erez Volk

import Testing
@testable import Droneroo

struct DronerooTests {

    @Test func testNodeNameToMidi() async throws {
        #expect(parseNote("C") == 48)
        #expect(parseNote("D♭") == 49)
        #expect(parseNote("D♯") == 51)
    }

    @Test func testCFlatWraparound() async throws {
        #expect(parseNote("C♭") == 59)
        #expect(parseNote("Cb") == 59)
    }

    @Test func testBSharpWraparound() async throws {
        #expect(parseNote("B♯") == 48)
    }

    @Test func testDoubleFlat() async throws {
        #expect(parseNote("D𝄫") == 48)
        #expect(parseNote("E♭♭") == 50)
        #expect(parseNote("Fbb") == 51)
    }

    @Test func testDoubleSharp() async throws {
        #expect(parseNote("D𝄪") == 52)
        #expect(parseNote("Ex") == 54)
    }

    func parseNote(_ note: String) -> Int {
        return Int(DronerooLogic.noteNameToMidiNumber(note))
    }
}
