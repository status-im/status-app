import QtQuick
import QtTest
import StatusQ

TestCase {
    id: testCase
    name: "ChatInputHighlighter"

    property ChatInputHighlighter highlighter: ChatInputHighlighter {}
    property ChatInputHighlighter highlighterMultiLine: ChatInputHighlighter { multilineEmphasis: true }

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

    function spanForMultiLine(text, contentSubstring) {
        const spans = highlighterMultiLine.parseFormats(text)
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

    // ── multi-line emphasis ───────────────────────────────────────────────────

    function test_multiline_bold() {
        const s = spanForMultiLine("**bold\ncontent**", "bold\ncontent")
        verify(s !== null, "expected bold span across newline")
        verify(s.bold)
    }

    function test_multiline_italic() {
        const s = spanForMultiLine("*first line\nsecond line*", "first line\nsecond line")
        verify(s !== null, "expected italic span across newline")
        verify(s.italic)
    }

    function test_multiline_strikethrough() {
        const s = spanForMultiLine("~~line one\nline two~~", "line one\nline two")
        verify(s !== null, "expected strikethrough span across newline")
        verify(s.strikethrough)
    }

    function test_multiline_threeLines() {
        const s = spanForMultiLine("**first\nmiddle\nlast**", "first\nmiddle\nlast")
        verify(s !== null, "expected bold span across three lines")
        verify(s.bold)
    }

    function test_multiline_independentSingleLineSpansUnaffected() {
        // Single-line spans on separate lines must still work
        const text  = "**bold**\n*italic*"
        const bspan = spanForMultiLine(text, "bold")
        const ispan = spanForMultiLine(text, "italic")
        verify(bspan !== null && bspan.bold,   "bold span must still match")
        verify(ispan !== null && ispan.italic, "italic span must still match")
    }

    // ── multilineEmphasis: false (default) — cross-line spans must not form ──

    function test_multilineDisabled_noCrossLineBold() {
        compare(highlighter.parseFormats("**bold\ncontent**").length, 0)
    }

    function test_multilineDisabled_noCrossLineItalic() {
        compare(highlighter.parseFormats("*first\nsecond*").length, 0)
    }

    function test_multilineDisabled_noCrossLineStrikethrough() {
        compare(highlighter.parseFormats("~~line one\nline two~~").length, 0)
    }

    function test_multilineDisabled_singleLineSpansStillWork() {
        const text  = "**bold**\n*italic*"
        const bspan = spanFor(text, "bold")
        const ispan = spanFor(text, "italic")
        verify(bspan !== null && bspan.bold,   "single-line bold must still work")
        verify(ispan !== null && ispan.italic, "single-line italic must still work")
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

    // ── delimiter positions ───────────────────────────────────────────────────

    function delimFor(text, delimStr, fromPos) {
        // finds the delimiter entry whose [start,end) = [fromPos, fromPos+delimStr.length)
        const delims = highlighter.parseDelimiters(text)
        for (let i = 0; i < delims.length; i++) {
            if (delims[i].start === fromPos &&
                delims[i].end   === fromPos + delimStr.length)
                return delims[i]
        }
        return null
    }

    function test_delimiter_boldOpenerAndCloser() {
        // "**bold**": opener=[0,2), closer=[6,8)
        verify(delimFor("**bold**", "**", 0) !== null, "bold opener missing")
        verify(delimFor("**bold**", "**", 6) !== null, "bold closer missing")
    }

    function test_delimiter_italicOpenerAndCloser() {
        // "*italic*": opener=[0,1), closer=[7,8)
        verify(delimFor("*italic*", "*", 0) !== null, "italic opener missing")
        verify(delimFor("*italic*", "*", 7) !== null, "italic closer missing")
    }

    function test_delimiter_strikethroughOpenerAndCloser() {
        // "~~strike~~": opener=[0,2), closer=[8,10)
        verify(delimFor("~~strike~~", "~~", 0) !== null, "strikethrough opener missing")
        verify(delimFor("~~strike~~", "~~", 8) !== null, "strikethrough closer missing")
    }

    function test_delimiter_unmatchedNotReturned() {
        compare(highlighter.parseDelimiters("*unclosed").length, 0)
        compare(highlighter.parseDelimiters("unclosed*").length, 0)
    }

    function test_delimiter_boldItalicTripleStar() {
        // "***foo***": positions 0,1,2 and 6,7,8 are all delimiters
        const text = "***foo***"
        const delims = highlighter.parseDelimiters(text)
        // 2 spans × 2 delimiter runs = 4 entries
        compare(delims.length, 4)
        // collect all covered positions
        let covered = new Set()
        for (let i = 0; i < delims.length; i++)
            for (let p = delims[i].start; p < delims[i].end; p++)
                covered.add(p)
        for (let p = 0; p <= 2; p++)
            verify(covered.has(p), "position " + p + " must be a delimiter")
        for (let p = 6; p <= 8; p++)
            verify(covered.has(p), "position " + p + " must be a delimiter")
    }

    function test_delimiter_count_bold() {
        compare(highlighter.parseDelimiters("**bold**").length, 2)
    }

    function test_delimiter_noDelimitersInPlainText() {
        compare(highlighter.parseDelimiters("hello world").length, 0)
    }

    // ── code span / emphasis interaction ──────────────────────────────────────

    function test_codeSpan_delimsInsideCodeDoNotConsumeOutsideDelims() {
        // "`A**B` C **D**": D must be bold; C must not be bold
        const text  = "`A**B` C **D**"
        const spans = highlighter.parseFormats(text)
        let hasBoldD = false
        let hasBoldC = false
        for (let i = 0; i < spans.length; i++) {
            if (!spans[i].bold) continue
            for (let p = spans[i].start; p < spans[i].end; p++) {
                if (text[p] === 'D') hasBoldD = true
                if (text[p] === 'C') hasBoldC = true
            }
        }
        verify(hasBoldD,  "D should be bold")
        verify(!hasBoldC, "C must not be bold")
    }

    function test_codeSpan_emphasisAfterMultipleCodeSpans() {
        // Two code spans then **bold**: bold must match correctly
        const text  = "`a` `b` **bold**"
        const spans = highlighter.parseFormats(text)
        let boldSpan = null
        for (let i = 0; i < spans.length; i++)
            if (spans[i].bold) boldSpan = spans[i]
        verify(boldSpan !== null, "expected a bold span")
        compare(boldSpan.start, text.indexOf("bold"))
        compare(boldSpan.end,   text.indexOf("bold") + 4)
    }

    function test_inlineCode_basic() {
        // "`hello`": content = [1, 6)
        const spans = highlighter.parseCodeSpans("`hello`")
        compare(spans.length, 1)
        compare(spans[0].start, 1)
        compare(spans[0].end,   6)
    }

    function test_inlineCode_unmatchedNotReturned() {
        compare(highlighter.parseCodeSpans("`unclosed").length, 0)
        compare(highlighter.parseCodeSpans("unclosed`").length, 0)
    }

    function test_inlineCode_noFormattingInsideCode() {
        // **bold** inside backticks must not produce emphasis spans
        const spans = highlighter.parseFormats("`**not bold**`")
        for (let i = 0; i < spans.length; i++)
            verify(!spans[i].bold, "bold must not apply inside code span")
    }

    function test_inlineCode_delimitersBlue() {
        // backtick markers at [0,1) and [6,7) must appear as delimiter entries
        verify(delimFor("`hello`", "`", 0) !== null, "opener delimiter missing")
        verify(delimFor("`hello`", "`", 6) !== null, "closer delimiter missing")
    }

    function test_inlineCode_plainText() {
        compare(highlighter.parseCodeSpans("hello world").length, 0)
    }

    // ── triple-backtick code fence ─────────────────────────────────────────────

    function test_tripleBacktick_basic() {
        // "```hello```": content = [3, 8)
        const spans = highlighter.parseCodeSpans("```hello```")
        compare(spans.length, 1)
        compare(spans[0].start, 3)
        compare(spans[0].end,   8)
    }

    function test_tripleBacktick_noFormattingInsideFence() {
        const spans = highlighter.parseFormats("```**not bold**```")
        for (let i = 0; i < spans.length; i++)
            verify(!spans[i].bold, "bold must not apply inside code fence")
    }

    function test_tripleBacktick_delimiters() {
        verify(delimFor("```hi```", "```", 0) !== null, "fence opener delimiter missing")
        verify(delimFor("```hi```", "```", 5) !== null, "fence closer delimiter missing")
    }

    // ── single vs triple backtick do not cross-match ───────────────────────────

    function test_code_singleAndTripleDoNotCrossMatch() {
        // "``foo`" — opener is 2 backticks, only one closer backtick → no match
        compare(highlighter.parseCodeSpans("``foo`").length, 0)
    }

    // ── multiline code (multilineEmphasis: true) ───────────────────────────────

    function test_multiline_inlineCode() {
        const spans = highlighterMultiLine.parseCodeSpans("`first\nsecond`")
        compare(spans.length, 1)
        compare(spans[0].start, 1)
        compare(spans[0].end,   13)
    }

    function test_multiline_tripleBacktick() {
        const spans = highlighterMultiLine.parseCodeSpans("```first\nsecond```")
        compare(spans.length, 1)
        compare(spans[0].start, 3)
        compare(spans[0].end,   15)
    }

    // ── multilineEmphasis: false — single-backtick does not cross lines ─────────

    function test_multilineDisabled_inlineCodeDoesNotCrossLines() {
        compare(highlighter.parseCodeSpans("`first\nsecond`").length, 0)
    }

    // ── triple-backtick is always multiline, even with multilineEmphasis: false ─

    function test_tripleBacktick_alwaysMultiline() {
        // highlighter has multilineEmphasis: false, but ``` fences still cross lines
        const spans = highlighter.parseCodeSpans("```first\nsecond```")
        compare(spans.length, 1)
        compare(spans[0].start, 3)
        compare(spans[0].end,   15)
    }
}
