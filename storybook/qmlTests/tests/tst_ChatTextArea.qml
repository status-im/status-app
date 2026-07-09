import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest

        ChatTextArea {
            anchors.fill: parent
        }
    }

    // A plain editor used to read back the clipboard's external (plain-text) form.
    Component {
        id: plainTextEditComponent

        TextEdit {}
    }

    // Helper views to read the (highlighter-backed) models from QML. They bind to the
    // control created per-test; `.count` / `itemAt` expose row count and roles.
    Repeater {
        id: mentionsRepeater
        model: testCase.control ? testCase.control.mentionsModel : null
        delegate: Item {
            required property int position
            required property string name
            required property string pubKey
        }
    }

    Repeater {
        id: linksRepeater
        model: testCase.control ? testCase.control.linksModel : null
        delegate: Item {
            required property string text
            required property int start
            required property int length
        }
    }

    TestCase {
        id: testCase
        name: "ChatTextArea"
        when: windowShown

        property ChatTextArea control: null

        function init() {
            control = createTemporaryObject(componentUnderTest, root)
            verify(control)
        }

        // ── triple-backtick interception ────────────────────────────────────────

        // Typing the 3rd backtick right after "``" completes the fence as "```",
        // performed as our own edit (see TextDocumentUtils.handleTripleBacktick).
        function test_tripleBacktick_completesFence() {
            control.text = "``"
            control.cursorPosition = 2
            control.forceActiveFocus()

            keyClick(Qt.Key_QuoteLeft)

            compare(control.text, "```")
            compare(control.cursorPosition, 3)
        }

        // Without two preceding backticks the keystroke inserts normally.
        function test_tripleBacktick_normalInsertWhenNotTwoBackticks() {
            control.text = "ab"
            control.cursorPosition = 2
            control.forceActiveFocus()

            keyClick(Qt.Key_QuoteLeft)

            compare(control.text, "ab`")
        }

        // With an active selection the interception is suppressed; the typed backtick
        // replaces the selection.
        function test_tripleBacktick_suppressedWithSelection() {
            control.text = "``"
            control.select(0, 2)
            control.forceActiveFocus()

            keyClick(Qt.Key_QuoteLeft)

            compare(control.text, "`")
        }

        // ── insertMention ───────────────────────────────────────────────────────

        // A mention is one embedded object (ObjectReplacementCharacter, U+FFFC).
        function test_insertMention_insertsObjectChar() {
            control.text = ""
            control.insertMention(0, "@alice", "0xabc")

            compare(control.length, 1)
            compare(control.getText(0, 1).charCodeAt(0), 0xFFFC)
        }

        // insertMention surfaces in the exposed mentionsModel with its roles.
        function test_insertMention_populatesMentionsModel() {
            control.text = ""
            control.insertMention(0, "@alice", "0xabc")

            tryCompare(mentionsRepeater, "count", 1)

            const item = mentionsRepeater.itemAt(0)
            verify(item)
            compare(item.position, 0)
            compare(item.name, "@alice")
            compare(item.pubKey, "0xabc")
        }

        // ── textual round-trip: getText / loadText ──────────────────────────────

        // getText() serializes each mention pill to its "@"+pubKey wire form.
        function test_getText_serializesMentionToPubKey() {
            control.text = ""
            control.insertMention(0, "@alice", "0xabc")
            compare(control.textWithMentions(), "@0xabc")
        }

        // loadText() detects textual mentions and rebuilds them as pills (name resolved from the
        // supplied map); getText() then round-trips back to the same wire text.
        function test_loadText_buildsPillsAndRoundTrips() {
            const key = "0x" + "a".repeat(130) // a detectable uncompressed key
            const names = {}
            names[key] = "Alice"
            names["0x00001"] = "everyone"

            const wire = "hi @" + key + " and @0x00001 done"
            control.loadText(wire, names)

            tryCompare(mentionsRepeater, "count", 2)

            const a = mentionsRepeater.itemAt(0)
            const b = mentionsRepeater.itemAt(1)
            compare(a.pubKey, key)
            compare(a.name, "@Alice")
            compare(b.pubKey, "0x00001")
            compare(b.name, "@everyone")

            compare(control.textWithMentions(), wire)
        }

        // Unknown pub keys fall back to the pub key itself; the system tag to "everyone".
        function test_loadText_fallbackNames() {
            control.loadText("@0x00001", ({}))
            tryCompare(mentionsRepeater, "count", 1)
            compare(mentionsRepeater.itemAt(0).name, "@everyone")
            compare(control.textWithMentions(), "@0x00001")
        }

        // ── emoji shortcode context (":" trigger) ───────────────────────────────

        // ":" at text start + two token chars ⇒ entering, filter is the typed shortcode.
        function test_enteringEmoji_triggersAfterTwoChars() {
            control.text = ":ab"
            control.cursorPosition = 3
            compare(control.enteringEmoji, true)
            compare(control.emojiFilter, "ab")
        }

        // A single char after ":" is not enough to trigger.
        function test_enteringEmoji_requiresTwoChars() {
            control.text = ":a"
            control.cursorPosition = 2
            compare(control.enteringEmoji, false)
        }

        // Digits and underscores are valid shortcode chars.
        function test_enteringEmoji_allowsDigitsAndUnderscore() {
            control.text = ":a_1"
            control.cursorPosition = 4
            compare(control.enteringEmoji, true)
            compare(control.emojiFilter, "a_1")
        }

        // The ":" must start a token (line start or after whitespace).
        function test_enteringEmoji_requiresTokenStart() {
            control.text = "x:ab"
            control.cursorPosition = 4
            compare(control.enteringEmoji, false)
        }

        // ":" right after whitespace triggers; filter is the text up to the caret.
        function test_enteringEmoji_afterWhitespace() {
            control.text = "hi :ab"
            control.cursorPosition = 6
            compare(control.enteringEmoji, true)
            compare(control.emojiFilter, "ab")
        }

        // A whitespace after the shortcode ends the token.
        function test_enteringEmoji_stopsAfterWhitespace() {
            control.text = ":ab "
            control.cursorPosition = 4
            compare(control.enteringEmoji, false)
        }

        // Shortcodes inside a code span are ignored.
        function test_enteringEmoji_notInCodeSpan() {
            control.text = "`:ab`"
            control.cursorPosition = 4 // between "b" and the closing backtick
            tryCompare(control, "enteringEmoji", false)
        }

        // ── mention demotion inside a (closing) code fence ──────────────────────

        // Initial document (formatUnclosedCodeFence stays off):
        //   ```        <- opening fence
        //   <mention>
        //   ``         <- incomplete closing fence
        // The fence is unclosed, so the mention is NOT yet code and stays a mention.
        // Typing the 3rd backtick completes the closing fence: the mention now sits
        // inside a closed code block and is demoted to its plain-text name. A single
        // undo must restore the original document with the mention back.
        function test_tripleBacktick_demotesMentionInClosedFence_undoRestores() {
            const M = String.fromCharCode(0xFFFC)

            control.text = "```\n"
            control.insertMention(control.length, "@alice", "0xabc") // M at index 4
            control.insert(control.length, "\n``")                   // -> ```\nM\n``
            control.forceActiveFocus()
            control.cursorPosition = control.length                  // end, after the ``

            // Unclosed fence -> still a mention.
            compare(control.text, "```\n" + M + "\n``")
            tryCompare(mentionsRepeater, "count", 1)

            // Complete the closing fence; the mention falls inside code and demotes.
            keyClick(Qt.Key_QuoteLeft)
            tryCompare(control, "text", "```\n@alice\n```")
            tryCompare(mentionsRepeater, "count", 0)

            // A single undo restores both the closing fence and the mention.
            keyClick(Qt.Key_Z, Qt.ControlModifier)
            compare(control.text, "```\n" + M + "\n``")
            tryCompare(mentionsRepeater, "count", 1)
            compare(mentionsRepeater.itemAt(0).name, "@alice")
            compare(mentionsRepeater.itemAt(0).pubKey, "0xabc")
        }

        // Mirror of the above, but the incomplete fence is the OPENING one:
        //   ``         <- incomplete opening fence
        //   <mention>
        //   ```        <- complete closing fence
        // Line 3's ``` is just a lone unclosed opener, so the mention isn't code yet.
        // Typing the 3rd backtick at the top completes the opening fence; the mention
        // now sits inside a closed code block and demotes. A single undo restores it.
        function test_tripleBacktick_completesOpeningFence_undoRestores() {
            const M = String.fromCharCode(0xFFFC)

            control.text = "``\n"
            control.insertMention(control.length, "@alice", "0xabc") // M at index 3
            control.insert(control.length, "\n```")                  // -> ``\nM\n```
            control.forceActiveFocus()
            control.cursorPosition = 2                               // end of line 1, after the ``

            // Lone opener below -> still a mention.
            compare(control.text, "``\n" + M + "\n```")
            tryCompare(mentionsRepeater, "count", 1)

            // Complete the opening fence; the mention falls inside code and demotes.
            keyClick(Qt.Key_QuoteLeft)
            tryCompare(control, "text", "```\n@alice\n```")
            tryCompare(mentionsRepeater, "count", 0)

            // A single undo restores both the opening fence and the mention.
            keyClick(Qt.Key_Z, Qt.ControlModifier)
            compare(control.text, "``\n" + M + "\n```")
            tryCompare(mentionsRepeater, "count", 1)
            compare(mentionsRepeater.itemAt(0).name, "@alice")
            compare(mentionsRepeater.itemAt(0).pubKey, "0xabc")
        }

        // Deleting a backtick can re-pair fences so a previously-outside mention ends
        // up inside code. Initial (single line, spaces around the mention):
        //   ```A``` <mention> ```
        // The first ``` pairs with the second (code block "A"); the trailing ``` is
        // unmatched, so the mention is NOT in code. Removing the first backtick leaves
        //   ``A``` <mention> ```
        // now the two remaining ``` runs pair, wrapping " <mention> " in a code block,
        // so the mention demotes.
        //
        // Deleting the first backtick is performed by ChatTextArea as a raw, joinable
        // edit, so the reactive demotion folds into the same undo command — a single
        // undo restores both the deleted backtick and the mention.
        function test_deleteBacktick_repairsFenceDemotesMention_undoRestores() {
            const M = String.fromCharCode(0xFFFC)
            const initial = "```A``` " + M + " ```"

            control.text = "```A``` "
            control.insertMention(control.length, "@alice", "0xabc")
            control.insert(control.length, " ```")            // -> ```A``` M ```
            compare(control.text, initial)
            tryCompare(mentionsRepeater, "count", 1)           // outside code -> still a mention

            control.forceActiveFocus()
            control.cursorPosition = 1
            keyClick(Qt.Key_Backspace)                         // delete the first backtick

            // Re-paired fences put the mention inside code -> demoted to plain text.
            tryCompare(control, "text", "``A``` " + "@alice" + " ```")
            tryCompare(mentionsRepeater, "count", 0)

            // A single undo restores both the deleted backtick and the mention.
            keyClick(Qt.Key_Z, Qt.ControlModifier)
            compare(control.text, initial)
            tryCompare(mentionsRepeater, "count", 1)
            compare(mentionsRepeater.itemAt(0).name, "@alice")
            compare(mentionsRepeater.itemAt(0).pubKey, "0xabc")
        }

        // Plain deletions (no backtick/mention in the removed range) fall through to
        // native handling, so consecutive backspaces keep Qt's undo coalescing: three
        // backspaces deleting "AAA" undo as a single step.
        function test_backspacePlainText_singleUndoRestores() {
            control.text = "AAA"
            control.forceActiveFocus()
            control.cursorPosition = control.length

            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            compare(control.text, "")

            keyClick(Qt.Key_Z, Qt.ControlModifier) // single undo
            compare(control.text, "AAA")
        }

        // The highlighter enlarges emojis to fill the line height (they render smaller
        // than text otherwise), without making the line taller.
        function test_emoji_enlargedWithoutGrowingLine() {
            control.text = "AAA"
            control.forceActiveFocus()
            const plainLineH = control.positionToRectangle(0).height

            control.text = "A\u{1F60E}A" // A 😎 A; the emoji is a surrogate pair (positions 1..3)
            function emojiAdvance() {
                return control.positionToRectangle(3).x - control.positionToRectangle(1).x
            }

            // The (async) highlight grows the emoji's advance to ~the line height.
            tryVerify(() => emojiAdvance() >= plainLineH * 0.9)

            // ...but the line itself stays the same height.
            compare(control.positionToRectangle(0).height, plainLineH)
        }

        // With enlargeEmojis off, the emoji keeps its base size (not grown to the line).
        function test_emoji_enlargingCanBeDisabled() {
            control.enlargeEmojis = false

            control.text = "AAA"
            control.forceActiveFocus()
            const plainLineH = control.positionToRectangle(0).height

            control.text = "A\u{1F60E}A"
            const emojiAdvance = control.positionToRectangle(3).x - control.positionToRectangle(1).x

            // not enlarged -> advance stays clearly below the line height
            verify(emojiAdvance < plainLineH * 0.9)
        }

        // ── quoteBarVisible ─────────────────────────────────────────────────────

        function test_quoteBarVisible_defaultsTrueAndSettable() {
            compare(control.quoteBarVisible, true)
            control.quoteBarVisible = false
            compare(control.quoteBarVisible, false)
        }

        // ── quote continuation / atomic "> " editing ───────────────────────────

        // Enter inside a quote line starts a new "> " continuation line.
        function test_quoteEnterContinues() {
            control.text = "> A"
            control.forceActiveFocus()
            control.cursorPosition = control.length

            keyClick(Qt.Key_Return)

            compare(control.text, "> A\n> ")
            compare(control.cursorPosition, control.length)
        }

        // Enter on an empty quote line whose previous line is also an empty quote
        // line drops both, exiting the quote.
        function test_quoteDoubleEnterExits() {
            control.text = "> A\n> \n> "
            control.forceActiveFocus()
            control.cursorPosition = control.length

            keyClick(Qt.Key_Return)

            // The two trailing empty quote lines are gone; only "> A" remains quoted.
            verify(!control.text.endsWith("> "))
            compare(control.text, "> A\n")
        }

        // A single Backspace at the start of quote content removes the whole "> "
        // prefix (not the space then the ">" separately).
        function test_quoteBackspaceRemovesPrefix() {
            control.text = "> A"
            control.forceActiveFocus()
            control.cursorPosition = 2 // content start, right after "> "

            keyClick(Qt.Key_Backspace)

            compare(control.text, "A")
        }

        // The caret cannot sit inside the "> " prefix; it snaps to the content start.
        function test_quoteCaretSnap() {
            control.text = "> A"
            control.forceActiveFocus()
            control.cursorPosition = 1 // inside the "> " prefix

            tryCompare(control, "cursorPosition", 2)
        }

        // Delete at the end of a non-empty line before a quote joins the lines, dropping
        // the whole "\n> " (separator + prefix) so the content merges cleanly.
        function test_quoteDeleteJoinsNonEmptyLine() {
            control.text = "A\n> B"
            control.forceActiveFocus()
            control.cursorPosition = 1 // end of "A"

            keyClick(Qt.Key_Delete)

            compare(control.text, "AB")
        }

        // Delete at the end of an empty line before a quote removes only the paragraph
        // separator (not the "> "); the caret snap then lands at the quote content start.
        function test_quoteDeleteFromEmptyLine() {
            control.text = "\n> B"
            control.forceActiveFocus()
            control.cursorPosition = 0 // the empty first line

            keyClick(Qt.Key_Delete)

            compare(control.text, "> B")
            tryCompare(control, "cursorPosition", 2) // snapped past "> "
        }

        // Right arrow crossing into a quote line skips the "> " prefix in a single press
        // (native moves into the prefix, the caret snap forwards it to the content start).
        function test_quoteRightArrowSkipsPrefix() {
            control.text = "> A\n> B"
            control.forceActiveFocus()
            control.cursorPosition = 3 // end of the first quote line

            keyClick(Qt.Key_Right)

            tryCompare(control, "cursorPosition", 6) // content start of line 2, past "> "
        }

        // Left arrow at a quote line's content start jumps to the end of the previous
        // line rather than stepping into the "> " prefix.
        function test_quoteLeftArrowJumpsToPrevLine() {
            control.text = "> A\n> B"
            control.forceActiveFocus()
            control.cursorPosition = 6 // content start of line 2

            keyClick(Qt.Key_Left)

            compare(control.cursorPosition, 3) // end of line 1
        }

        // Outer strikethrough must not bleed onto a code span's backtick markers (they keep
        // their own kCode style). "~~`A`~~": ~~ at 0-1, ` at 2, A at 3, ` at 4, ~~ at 5-6.
        function test_codeSpanDelimitersNoStrikethroughBleed() {
            control.text = "~~`A`~~"
            control.forceActiveFocus()

            // Wait until the (async) highlight has struck the code content "A"...
            tryVerify(() => control.emphasisAt(3).strikethrough)
            // ...the backtick markers must NOT be struck.
            verify(!control.emphasisAt(2).strikethrough, "opening backtick must not be struck")
            verify(!control.emphasisAt(4).strikethrough, "closing backtick must not be struck")
        }

        // A "> " inside a code block is not a real quote line, so Enter does not start a
        // continuation — it falls through to a plain newline.
        function test_quoteNoContinuationInCodeBlock() {
            control.text = "```\n> A\n```"
            control.forceActiveFocus()
            control.cursorPosition = control.text.indexOf("A") + 1 // end of the "> A" line

            keyClick(Qt.Key_Return)

            compare(control.text, "```\n> A\n\n```") // plain newline, no new "> "
        }

        // ── mention suggestion context (enteringSuggestion / mentionsFilter) ──────

        // Sets text + caret and checks the two derived properties.
        function checkMention(text, cursor, entering, filter) {
            control.text = text
            control.forceActiveFocus()
            control.cursorPosition = cursor

            tryCompare(control, "enteringSuggestion", entering)
            tryCompare(control, "mentionsFilter", filter)
        }

        // A bare "@" (at text start) starts a suggestion with an empty filter.
        function test_mention_atStartEmptyFilter() {
            checkMention("@", 1, true, "")
        }

        // "@ab" -> entering, filter is the partial name.
        function test_mention_partialName() {
            checkMention("@ab", 3, true, "ab")
        }

        // An "@" right after a space is a valid anchor.
        function test_mention_afterSpace() {
            checkMention("hi @ab", 6, true, "ab")
        }

        // Caret in the middle of the token: filter is up to the caret.
        function test_mention_midToken() {
            checkMention("@abc", 2, true, "a")
        }

        // "@" glued to a word char (a@ab) is not a mention anchor.
        function test_mention_notAnchoredAfterWordChar() {
            checkMention("a@ab", 4, false, "")
        }

        // Whitespace between the "@" token and the caret breaks the suggestion.
        function test_mention_whitespaceBreaks() {
            checkMention("@a b", 4, false, "")
        }

        // Caret before the "@" is not entering a suggestion.
        function test_mention_caretBeforeAt() {
            checkMention("@ab", 0, false, "")
        }

        // A space-anchored "@" that lands inside an inline code span is suppressed.
        function test_mention_suppressedInCodeSpan() {
            checkMention("`a @b`", 5, false, "")
        }

        // An "@" inside a fenced code block is suppressed.
        function test_mention_suppressedInCodeBlock() {
            checkMention("```\n@ab\n```", 7, false, "")
        }

        // ── copy / cut / paste with mentions ─────────────────────────────────────

        // Builds "A<mention>B" and returns the object char for assertions.
        function makeMentionDoc() {
            const M = String.fromCharCode(0xFFFC)
            control.text = "A"
            control.insertMention(1, "@alice", "0xabc")
            control.insert(control.length, "B")
            compare(control.text, "A" + M + "B")
            tryCompare(mentionsRepeater, "count", 1)
            return M
        }

        // Copy a selection with a mention, clear, and paste it back: the mention object is
        // rebuilt (roles preserved) from the private clipboard MIME.
        function test_copyPaste_mentionRoundTrip() {
            const M = makeMentionDoc()
            control.forceActiveFocus()
            control.selectAll()
            keyClick(Qt.Key_C, Qt.ControlModifier)

            control.text = ""
            control.cursorPosition = 0
            keyClick(Qt.Key_V, Qt.ControlModifier)

            tryCompare(control, "text", "A" + M + "B")
            tryCompare(mentionsRepeater, "count", 1)
            compare(mentionsRepeater.itemAt(0).name, "@alice")
            compare(mentionsRepeater.itemAt(0).pubKey, "0xabc")
        }

        // Cut removes the selection (and its mention); a subsequent paste restores it.
        function test_cut_removesSelectionThenPasteRestores() {
            const M = makeMentionDoc()
            control.forceActiveFocus()
            control.selectAll()
            keyClick(Qt.Key_X, Qt.ControlModifier)

            tryCompare(control, "text", "")
            tryCompare(mentionsRepeater, "count", 0)

            control.cursorPosition = 0
            keyClick(Qt.Key_V, Qt.ControlModifier)
            tryCompare(control, "text", "A" + M + "B")
            tryCompare(mentionsRepeater, "count", 1)
        }

        // The clipboard's plain-text form renders the mention as its name, so pasting into a
        // plain editor yields "A@aliceB".
        function test_copy_externalPlainText() {
            makeMentionDoc()
            control.forceActiveFocus()
            control.selectAll()
            keyClick(Qt.Key_C, Qt.ControlModifier)

            const plain = createTemporaryObject(plainTextEditComponent, root)
            verify(plain)
            plain.forceActiveFocus()
            plain.paste()
            tryCompare(plain, "text", "A@aliceB")
        }
    }
}
