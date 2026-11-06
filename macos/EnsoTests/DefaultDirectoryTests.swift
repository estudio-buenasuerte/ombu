import Foundation
import Testing
@testable import Enso

struct DefaultDirectoryTests {
    @Test func expandsTildePath() {
        #expect(DefaultDirectory.parse("working-directory = ~/Developer", home: "/Users/test") == "/Users/test/Developer")
    }

    @Test func expandsQuotedTildePath() {
        #expect(DefaultDirectory.parse("working-directory = \"~/Developer\"", home: "/Users/test") == "/Users/test/Developer")
    }

    @Test func homeMeansDefault() {
        #expect(DefaultDirectory.parse("working-directory = home") == nil)
    }

    @Test func inheritMeansDefault() {
        #expect(DefaultDirectory.parse("working-directory = inherit") == nil)
    }

    @Test func missingKeyMeansDefault() {
        #expect(DefaultDirectory.parse("font-size = 14") == nil)
    }

    @Test func ignoresTrailingComment() {
        #expect(DefaultDirectory.parse("working-directory = ~/Developer # comment", home: "/Users/test") == "/Users/test/Developer")
    }

    @Test func lastAssignmentWins() {
        #expect(DefaultDirectory.parse("working-directory = /first\nworking-directory = /last") == "/last")
    }

    @Test func tildeAloneMeansHome() {
        #expect(DefaultDirectory.parse("working-directory = ~", home: "/Users/test") == "/Users/test")
    }
}
