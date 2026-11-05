import Testing
@testable import Enso

struct ChromeFontTests {
    @Test func ignoresCommentsAndBlankLines() {
        let text = """
        # font-family = Commented

          # Another comment
        font-family = Example Family # Inline comment

        """
        #expect(ChromeFont.parse(text) == ["font-family": "Example Family"])
    }

    @Test func trimsSpacing() {
        #expect(ChromeFont.parse(" \tfont-family\t = \tExample Family  \r\n")["font-family"] == "Example Family")
    }

    @Test func lastKeyWins() {
        let text = "font-family = First\nfont-family = Second"
        #expect(ChromeFont.parse(text)["font-family"] == "Second")
    }

    @Test func ignoresUnknownKeys() {
        let text = "font-size = 14\nunknown = value\nfont-family = Example Family"
        #expect(ChromeFont.parse(text) == ["font-family": "Example Family"])
    }

    @Test func missingKeyIsNil() {
        #expect(ChromeFont.parse("")["font-family"] == nil)
        #expect(ChromeFont.parse("# Only a comment\nfont-size = 14\ninvalid line")["font-family"] == nil)
    }

    @Test func emptyValueOverridesEarlierFamily() {
        #expect(ChromeFont.parse("font-family = First\nfont-family =  ")["font-family"] == "")
    }
}
