import QtQuick
import QtTest
import StatusQ

TestCase {
    id: testCase
    name: "ChatInputHighlighter"

    property ChatInputHighlighter highlighter: ChatInputHighlighter {}

    // Returns the one span whose [start, end) exactly covers contentSubstring
    // inside text, or null if no such span exists.
    function spanFor(text, contentSubstring) {
        const spans = highlighter.parseFormats(text)
        const idx   = text.indexOf(contentSubstring)
        for (let i = 0; i < spans.length; i++) {
            if (spans[i].start === idx && spans[i].end === idx + contentSubstring.length)
                return spans[i]
        }
        return null
    }

    // ── bold ──────────────────────────────────────────────────────────────────

    function test_boldBasic() {
        const s = spanFor("**bold**", "bold")
        verify(s !== null, "expected a span over 'bold'")
        verify(s.bold,    "expected bold")
        verify(!s.italic, "must not be italic")
    }

    function test_boldDelimitersNotFormatted() {
        // The ** markers (positions 0-1 and 6-7) must not be inside any span
        const spans = highlighter.parseFormats("**bold**")
        for (let i = 0; i < spans.length; i++) {
            verify(spans[i].start >= 2, "opening ** must not be formatted")
            verify(spans[i].end   <= 6, "closing ** must not be formatted")
        }
    }

    function test_boldWithSurroundingText() {
        const s = spanFor("hello **world** there", "world")
        verify(s !== null)
        verify(s.bold)
    }

    function test_boldDelimiterPositionsExact() {
        // "**hi**": bold span must be exactly [2, 4)
        const spans = highlighter.parseFormats("**hi**")
        compare(spans.length, 1)
        compare(spans[0].start, 2)
        compare(spans[0].end,   4)
        verify(spans[0].bold)
    }

    // ── italic ────────────────────────────────────────────────────────────────

    function test_italicBasic() {
        const s = spanFor("*italic*", "italic")
        verify(s !== null)
        verify(s.italic)
        verify(!s.bold)
    }

    function test_italicDelimitersNotFormatted() {
        const spans = highlighter.parseFormats("*italic*")
        for (let i = 0; i < spans.length; i++) {
            verify(spans[i].start >= 1, "opening * must not be formatted")
            verify(spans[i].end   <= 7, "closing * must not be formatted")
        }
    }

    function test_italicDelimiterPositionsExact() {
        // "*hi*": italic span must be exactly [1, 3)
        const spans = highlighter.parseFormats("*hi*")
        compare(spans.length, 1)
        compare(spans[0].start, 1)
        compare(spans[0].end,   3)
        verify(spans[0].italic)
    }

    // ── strikethrough ─────────────────────────────────────────────────────────

    function test_strikethroughBasic() {
        const s = spanFor("~~strike~~", "strike")
        verify(s !== null)
        verify(s.strikethrough)
        verify(!s.bold)
        verify(!s.italic)
    }

    function test_strikethroughDelimiterPositionsExact() {
        // "~~hi~~": strikethrough span must be exactly [2, 4)
        const spans = highlighter.parseFormats("~~hi~~")
        compare(spans.length, 1)
        compare(spans[0].start, 2)
        compare(spans[0].end,   4)
        verify(spans[0].strikethrough)
    }

    function test_singleTildeNotFormatted() {
        // ~word~ must produce no spans — only ~~ is supported
        compare(highlighter.parseFormats("~word~").length, 0)
    }

    function test_tripleTildeNotFormatted() {
        compare(highlighter.parseFormats("~~~word~~~").length, 0)
    }

    // ── bold + italic ─────────────────────────────────────────────────────────

    function test_boldItalicTripleStar() {
        // ***foo*** → "foo" (positions 3–6) must be covered by both a bold
        // and an italic span
        const spans = highlighter.parseFormats("***foo***")
        let boldSpan   = null
        let italicSpan = null
        for (let i = 0; i < spans.length; i++) {
            if (spans[i].bold)   boldSpan   = spans[i]
            if (spans[i].italic) italicSpan = spans[i]
        }
        verify(boldSpan   !== null, "expected bold span")
        verify(italicSpan !== null, "expected italic span")
        compare(boldSpan.start,   3)
        compare(boldSpan.end,     6)
        compare(italicSpan.start, 1)
        compare(italicSpan.end,   8)
    }

    // ── no formatting — negative cases ───────────────────────────────────────

    function test_spaceAfterOpeningDelimiter_bold() {
        // Whitespace is neutral: "** foo **" still produces a bold span over " foo "
        const s = spanFor("** foo **", " foo ")
        verify(s !== null, "expected a bold span over ' foo '")
        verify(s.bold, "expected bold")
    }

    function test_spaceBeforeClosingDelimiter_italic() {
        // Whitespace is neutral: "*not italic *" produces an italic span
        const s = spanFor("*not italic *", "not italic ")
        verify(s !== null, "expected an italic span over 'not italic '")
        verify(s.italic, "expected italic")
    }

    function test_emptyDelimiters() {
        compare(highlighter.parseFormats("****").length,  0)
        compare(highlighter.parseFormats("**").length,    0)
        compare(highlighter.parseFormats("~~~~").length,  0)
    }

    function test_plainText() {
        compare(highlighter.parseFormats("hello world").length, 0)
    }

    function test_emptyString() {
        compare(highlighter.parseFormats("").length, 0)
    }

    // ── multiple independent spans on one line ────────────────────────────────

    function test_boldAndItalicOnSameLine() {
        const text  = "**bold** and *italic*"
        const bspan = spanFor(text, "bold")
        const ispan = spanFor(text, "italic")
        verify(bspan !== null, "expected bold span")
        verify(ispan !== null, "expected italic span")
        verify(bspan.bold,    "bold span must be bold")
        verify(ispan.italic,  "italic span must be italic")
        verify(!bspan.italic, "bold span must not be italic")
        verify(!ispan.bold,   "italic span must not be bold")
    }

    // ── intraword emphasis ────────────────────────────────────────────────────

    function test_intrawordItalicAllowed() {
        // CommonMark: a*b*c is valid italic (left-flanking does not require
        // whitespace before the opening run)
        const s = spanFor("a*b*c", "b")
        verify(s !== null)
        verify(s.italic)
    }

    // ── unmatched delimiters ──────────────────────────────────────────────────

    function test_unmatchedOpeningDelimiter() {
        compare(highlighter.parseFormats("*unclosed").length, 0)
    }

    function test_unmatchedClosingDelimiter() {
        compare(highlighter.parseFormats("unclosed*").length, 0)
    }

    function test_mismatchedDelimiters_partialConsumption() {
        // **foo* — the closer has only 1 star so it can consume 1 char from
        // the opener; *foo* becomes italic, the leading * is unmatched.
        // At minimum: no crash, all positions are valid and start < end.
        const spans = highlighter.parseFormats("**foo*")
        for (let i = 0; i < spans.length; i++) {
            verify(spans[i].start >= 0,                        "start must be >= 0")
            verify(spans[i].end   <= 6,                        "end must be <= text length")
            verify(spans[i].start <  spans[i].end,             "start must be < end")
        }
    }
}
