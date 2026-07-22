import QtQuick
import QtTest

import StatusQ
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

    SignalSpy {
        id: limitSpy
        target: testCase.control
        signalName: "attemptToExceedHardLimit"
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

        // ── Shift+Enter behaves like Enter (no soft U+2028 line separator) ──────

        // Outside a quote, Shift+Enter inserts a real newline (a new block), not a U+2028
        // soft line separator that would stay inside the current block.
        function test_shiftEnter_insertsNewlineNotSoftBreak() {
            control.text = "ab"
            control.cursorPosition = 2
            control.forceActiveFocus()

            keyClick(Qt.Key_Return, Qt.ShiftModifier)

            compare(control.text, "ab\n")
            verify(control.text.indexOf("\u2028") === -1)
        }

        // Inside a quote, Shift+Enter continues the quote exactly like Enter ("\n> ").
        function test_shiftEnter_continuesQuoteLikeEnter() {
            control.text = "> hi"
            control.cursorPosition = 4
            control.forceActiveFocus()

            keyClick(Qt.Key_Return, Qt.ShiftModifier)

            compare(control.text, "> hi\n> ")
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
            skip() // TODO: this test is failing on CI, probably because of
                   // specific emoji font metrics on the CI machine
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

        // With fullLineHeightEmojis off, the emoji keeps its base size (not grown to the line).
        function test_emoji_enlargingCanBeDisabled() {
            control.fullLineHeightEmojis = false

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

        // Pasting over a selection replaces it in a single undo step: one Ctrl+Z restores the
        // replaced text directly (the selection removal and the insertion share one edit block),
        // with the caret left at the end of the restored text (not collapsed to its start).
        function test_pasteOverSelection_singleUndoRestores() {
            control.text = "abcde"
            control.forceActiveFocus()
            control.select(1, 3) // select "bc"
            ClipboardUtils.setText("XY")

            keyClick(Qt.Key_V, Qt.ControlModifier)
            tryCompare(control, "text", "aXYde")

            keyClick(Qt.Key_Z, Qt.ControlModifier)
            compare(control.text, "abcde")
            // Caret restored to the end of the originally-selected text ("bc"), not collapsed to
            // the document start.
            compare(control.cursorPosition, 3)
        }

        // ── hard character limit ────────────────────────────────────────────────

        function test_characterLimit_defaultsTo2000() {
            compare(control.characterLimit, 2000)
        }

        // Typing a character while the document is already at the limit is blocked before
        // insertion (text unchanged) and reports the attempt.
        function test_hardLimit_typingBlockedAtLimit() {
            control.characterLimit = 5
            control.text = "abcde"
            control.forceActiveFocus()
            control.cursorPosition = control.length

            limitSpy.clear()
            keyClick(Qt.Key_A)

            compare(control.text, "abcde")
            compare(limitSpy.count, 1)
        }

        // Typing below the limit inserts normally and does not report an attempt.
        function test_hardLimit_typingAllowedBelowLimit() {
            control.characterLimit = 5
            control.text = "abc"
            control.forceActiveFocus()
            control.cursorPosition = control.length

            limitSpy.clear()
            keyClick(Qt.Key_D)

            compare(control.text, "abcd")
            compare(limitSpy.count, 0)
        }

        // Typing that replaces a selection is allowed even at the limit, because the net length
        // does not grow.
        function test_hardLimit_selectionReplaceAllowedAtLimit() {
            control.characterLimit = 5
            control.text = "abcde"
            control.forceActiveFocus()
            control.select(0, 2) // replacing 2 chars with 1 keeps length within the cap

            limitSpy.clear()
            keyClick(Qt.Key_X)

            compare(control.text, "xcde")
            compare(limitSpy.count, 0)
        }

        // A paste that would exceed the limit is rejected whole (nothing inserted) and reports
        // the attempt.
        function test_hardLimit_pasteRejectedWhenExceeding() {
            control.characterLimit = 5
            control.text = ""
            control.forceActiveFocus()
            ClipboardUtils.setText("abcdefgh") // 8 > 5

            limitSpy.clear()
            keyClick(Qt.Key_V, Qt.ControlModifier)

            compare(control.text, "")
            compare(limitSpy.count, 1)
        }

        // A paste that fits is inserted and does not report an attempt.
        function test_hardLimit_pasteAllowedWhenFitting() {
            control.characterLimit = 5
            control.text = ""
            control.forceActiveFocus()
            ClipboardUtils.setText("ab")

            limitSpy.clear()
            keyClick(Qt.Key_V, Qt.ControlModifier)

            tryCompare(control, "text", "ab")
            compare(limitSpy.count, 0)
        }

        // Pasting over a selection fits when the replaced selection frees enough room, even
        // though the clipboard text alone would push the document over the cap.
        function test_hardLimit_pasteOverSelectionFits() {
            control.characterLimit = 5
            control.text = "abcde" // already at the limit
            control.forceActiveFocus()
            control.select(0, 3) // replacing "abc" frees room: 5 - 3 + 2 = 4 <= 5

            ClipboardUtils.setText("XY")

            limitSpy.clear()
            keyClick(Qt.Key_V, Qt.ControlModifier)

            tryCompare(control, "text", "XYde")
            compare(limitSpy.count, 0)
        }

        // Safety net: content inserted programmatically (bypassing Keys.onPressed) is trimmed
        // back to the limit by the onTextChanged backstop, and the attempt is reported.
        function test_hardLimit_safetyNetTrimsOverflow() {
            control.characterLimit = 5
            control.text = ""

            limitSpy.clear()
            control.insert(0, "abcdefgh") // 8 chars, not a key event

            compare(control.text, "abcde")
            compare(control.length, 5)
            compare(limitSpy.count, 1)
        }

        // ── image emojis (Twemoji) ──────────────────────────────────────────────

        // 😎 is U+1F60E — a 2-unit surrogate pair in the document string.
        readonly property string emoji: "\u{1F60E}"

        // Default (font-based) mode leaves emoji as raw Unicode in the document.
        function test_imageEmojis_defaultKeepsUnicode() {
            compare(control.imageEmojis, false)
            control.text = "A" + emoji + "B"
            compare(control.length, 4) // A + 2 surrogate units + B
            compare(control.textWithMentions(), "A" + emoji + "B")
        }

        // With image mode on, each emoji is replaced by a single inline image object (U+FFFC), and
        // the original Unicode is recovered by textWithMentions().
        function test_imageEmojis_convertsToImageObject() {
            control.imageEmojis = true
            control.text = "A" + emoji + "B"

            tryCompare(control, "length", 3) // A + <image ORC> + B
            compare(control.getText(1, 2).charCodeAt(0), 0xFFFC)
            compare(control.textWithMentions(), "A" + emoji + "B")
        }

        // Toggling image mode back off restores the raw emoji text (synchronously in the setter).
        function test_imageEmojis_toggleOffRestoresText() {
            control.imageEmojis = true
            control.text = "A" + emoji + "B"
            tryCompare(control, "length", 3)

            control.imageEmojis = false
            compare(control.length, 4)
            compare(control.textWithMentions(), "A" + emoji + "B")
        }

        // Copying an emoji image yields the Unicode emoji in the clipboard's external (plain-text)
        // form, so pasting into another app gets a real emoji.
        function test_imageEmojis_copyExternalPlainText() {
            control.imageEmojis = true
            control.text = emoji
            tryCompare(control, "length", 1) // single image ORC

            control.forceActiveFocus()
            control.selectAll()
            keyClick(Qt.Key_C, Qt.ControlModifier)

            const plain = createTemporaryObject(plainTextEditComponent, root)
            verify(plain)
            plain.forceActiveFocus()
            plain.paste()
            tryCompare(plain, "text", emoji)
        }

        // Emoji images and mentions coexist: the emoji becomes an image object while the mention
        // stays a mention (not counted among emoji images, nor emoji among mentions).
        function test_imageEmojis_coexistsWithMention() {
            control.imageEmojis = true
            control.text = ""
            control.insertMention(0, "@alice", "0xabc") // mention ORC at 0
            control.insert(control.length, emoji)       // raw emoji appended → converts to image

            tryCompare(control, "length", 2) // mention ORC + emoji image ORC
            tryVerify(() => control.textWithMentions() === "@0xabc" + emoji)
            tryCompare(mentionsRepeater, "count", 1)     // emoji image not counted as a mention
        }

        // insertTextWithEmojis inserts emoji as an image *synchronously* (no reactive queue), so the
        // raw Unicode never lands in the document — length reflects the ORC immediately.
        function test_imageEmojis_insertTextWithEmojisIsSynchronous() {
            control.imageEmojis = true
            control.text = ""

            control.insertTextWithEmojis(0, emoji + " ")

            // No tryCompare: the image is inserted in the same call, so length is already 2.
            compare(control.length, 2) // emoji image ORC + space
            compare(control.getText(0, 1).charCodeAt(0), 0xFFFC)
            compare(control.textWithMentions(), emoji + " ")
        }

        // In font mode the same call inserts plain text (no conversion).
        function test_imageEmojis_insertTextWithEmojisFontMode() {
            compare(control.imageEmojis, false)
            control.text = ""

            control.insertTextWithEmojis(0, emoji + " ")

            compare(control.length, 3) // 2 surrogate units + space
            compare(control.textWithMentions(), emoji + " ")
        }

        // Pasting emoji in image mode inserts the image directly (synchronously), so there is no
        // transient raw-Unicode length before the reactive conversion.
        function test_imageEmojis_pasteInsertsImageSynchronously() {
            control.imageEmojis = true
            control.text = ""
            control.forceActiveFocus()
            ClipboardUtils.setText("a" + emoji + "b")

            keyClick(Qt.Key_V, Qt.ControlModifier)

            // Directly after paste (no event-loop turn): a + image ORC + b == 3, not the transient 4.
            compare(control.length, 3)
            compare(control.getText(1, 2).charCodeAt(0), 0xFFFC)
            compare(control.textWithMentions(), "a" + emoji + "b")
        }

        // Two identical emoji placed back-to-back each become their own separately-rendered image
        // object. Qt merges adjacent fragments with identical char formats, which would collapse
        // them into a single (only-first-visible) image; a unique id per emoji keeps them apart.
        // emojiImageCount() counts by fragment, so it is 2 only when they stay separate — without
        // the unique id it would be 1 (this is the check that actually detects the bug).
        function test_imageEmojis_adjacentIdenticalEmoji() {
            control.imageEmojis = true
            control.text = ""

            control.insertTextWithEmojis(0, emoji + emoji)

            compare(control.length, 2)            // two ORCs
            compare(control.emojiImageCount(), 2) // ...kept as two distinct image fragments
            compare(control.textWithMentions(), emoji + emoji)
        }

        // ── nodeAt: AST-based caret formatting (delimiters belong to their node) ──────

        // Each sample is the document text with "|" marking the caret; "flags" lists exactly the
        // fields nodeAt must report as true there (every other field must be false). Because a
        // node's full range includes its delimiters, a caret next to a marker still counts as
        // inside — e.g. "*italics|*" is italic; only the outer boundaries ("|**bold**",
        // "**bold**|") fall outside.
        function test_nodeAt_data() {
            return [
                {tag: "italic incl. closing delimiter", text: "*italics|*",  flags: ["italic"]},
                {tag: "before italic (boundary)",       text: "|*italics*",  flags: []},
                {tag: "after italic (boundary)",        text: "*italics*|",  flags: []},
                {tag: "bold, between opening markers",  text: "*|*bold**",   flags: ["bold"]},
                {tag: "bold, after opening markers",    text: "**|bold**",   flags: ["bold"]},
                {tag: "bold, between closing markers",  text: "**bold*|*",   flags: ["bold"]},
                {tag: "before bold (boundary)",         text: "|**bold**",   flags: []},
                {tag: "after bold (boundary)",          text: "**bold**|",   flags: []},
                {tag: "code span nested in bold",       text: "**`code|`**", flags: ["bold", "codeSpan"]},
                {tag: "bold but before code span",      text: "*|*`code`**", flags: ["bold"]},
                {tag: "quote",                          text: "> qu|ote",    flags: ["quote"]},
                {tag: "code block",                     text: "```\nco|de\n```", flags: ["codeBlock"]},
                {tag: "plain text",                     text: "pl|ain",      flags: []},
            ]
        }

        function test_nodeAt(data) {
            const position = data.text.indexOf("|")
            control.text = data.text.replace("|", "") // strip the marker; its index is the caret

            const fields = ["bold", "italic", "strikethrough", "quote", "codeSpan", "codeBlock"]
            const matches = () => fields.every(
                f => control.nodeAt(position)[f] === (data.flags.indexOf(f) !== -1))

            verify(matches(), "nodeAt(" + position + ") for \"" + data.text + "\""
                   + " expected " + JSON.stringify(data.flags))
        }

        // ── removeFormatting: strip the delimiters of the node around the caret ──────

        // "input"/"output" embed the caret as "|". removeFormatting deletes the delimiters of the
        // node of "kind" strictly containing the caret, keeping the content and the caret's place
        // within it. It is a no-op when the caret is not inside such a node. "code" targets a code
        // span or a code block, whichever is found.
        function test_removeFormatting_data() {
            return [
                {tag: "caret in bold content",        input: "**bol|d**",     kind: "bold",   output: "bol|d"},
                {tag: "caret after opening markers",  input: "**|bold**",     kind: "bold",   output: "|bold"},
                {tag: "caret between opening markers", input: "*|*bold**",     kind: "bold",   output: "|bold"},
                {tag: "caret outside bold (no-op)",   input: "|**bold**",     kind: "bold",   output: "|**bold**"},
                {tag: "italics around code block",    input: "*```co|de```*", kind: "italic", output: "```co|de```"},
                {tag: "code span",                    input: "`co|de`",       kind: "code",   output: "co|de"},
                {tag: "code block",                   input: "```co|de```",   kind: "code",   output: "co|de"},
                {tag: "single-line quote",            input: "> qu|ote",      kind: "quote",  output: "qu|ote"},
                // Bold spanning quote lines nests the later "> " prefixes under the Strong node; all
                // four prefixes must still be removed.
                {tag: "multi-line quote with bold",
                 input:  "> |quote\n> **\n> bold\n> **",
                 kind:   "quote",
                 output: "|quote\n**\nbold\n**"},
                // A quoted code block holds the "> " prefixes as its own children; removing the code
                // must strip only the ``` fences and keep every quote prefix.
                {tag: "code block inside a quote",
                 input:  "> A\n> ```\n> B|\n> ```",
                 kind:   "code",
                 output: "> A\n> \n> B|\n> "},
            ]
        }

        function test_removeFormatting(data) {
            const position = data.input.indexOf("|")
            control.text = data.input.replace("|", "")
            control.cursorPosition = position

            control.removeFormatting(position, data.kind)

            compare(control.text, data.output.replace("|", ""))
            compare(control.cursorPosition, data.output.indexOf("|"))
        }

        // The whole strip is a single edit block, so one undo restores the original text exactly
        // and puts the caret back where it was (not at the start of the document).
        function test_removeFormatting_singleUndo() {
            control.text = "**bold**"
            control.cursorPosition = 4

            control.removeFormatting(4, "bold")
            compare(control.text, "bold")

            control.undo()
            compare(control.text, "**bold**")
            compare(control.cursorPosition, 4)
        }

        // ── delimitersAt: formatting implied by the delimiter run around the caret ──────

        // Purely local (no AST): the same delimiter char must flank the caret; its run length maps
        // to flags. "code" is span for 1-2 backticks, block for 3+. Context is ignored, so a caret
        // between "*"s inside a code fence still reports italic.
        function test_delimitersAt_data() {
            return [
                {tag: "bold",                    input: "**|**",                 flags: ["bold"]},
                {tag: "italic",                  input: "A *|*",                 flags: ["italic"]},
                {tag: "bold + italic",           input: "***|***",               flags: ["bold", "italic"]},
                {tag: "strikethrough",           input: "~~|~~",                 flags: ["strikethrough"]},
                {tag: "strikethrough, 3 tildes",  input: "~~~|~~~",               flags: ["strikethrough"]},
                {tag: "code span, 1 backtick",   input: "some `|`",              flags: ["codeSpan"]},
                {tag: "code span, 2 backticks",  input: "``|``",                 flags: ["codeSpan"]},
                {tag: "code block, 3 backticks", input: "some ```|```",          flags: ["codeBlock"]},
                {tag: "local only, ignores ctx", input: "```code *|* code```",   flags: ["italic"]},
                {tag: "asymmetric uses min run", input: "**|*",                  flags: ["italic"]},
                {tag: "single tilde is nothing", input: "~|~",                   flags: []},
                {tag: "mismatched delimiters",   input: "*|~",                   flags: []},
                {tag: "not a delimiter",         input: "ab|cd",                 flags: []},
                {tag: "at start (not enclosed)", input: "|**bold**",             flags: []},
                {tag: "at end (not enclosed)",   input: "**bold**|",             flags: []},
            ]
        }

        function test_delimitersAt(data) {
            const position = data.input.indexOf("|")
            control.text = data.input.replace("|", "")

            const fields = ["bold", "italic", "strikethrough", "codeSpan", "codeBlock"]
            const m = control.delimitersAt(position)
            fields.forEach(f => compare(m[f], data.flags.indexOf(f) !== -1,
                                        f + " for \"" + data.input + "\""))
        }

        // ── delimitersAtSelection: delimitersAt generalized to a selection ──────

        // Two "|" mark the selection bounds. The context is expanded past every delimiter flanking
        // the selection (so its own edge delimiters merge with the outer ones); the emitted flags
        // are those the outermost delimiter char at each end denotes (its inward run, both ends the
        // same char). Inner delimiters, or ones split off by non-delimiters, don't count.
        function test_delimitersAtSelection_data() {
            return [
                {tag: "bold",                      input: "A **|B|**",  flags: ["bold"]},
                {tag: "bold + italic",             input: "***|B|***",  flags: ["bold", "italic"]},
                {tag: "italic (asymmetric run)",   input: "**|B|*`*",   flags: ["italic"]},
                {tag: "italic, inner backticks",   input: "*|A`B`C|*",  flags: ["italic"]},
                {tag: "none (mismatched ends)",    input: "~`~|A|~*~",  flags: []},
                {tag: "strikethrough",             input: "~~|B|~~",    flags: ["strikethrough"]},
                {tag: "code span",                 input: "`|B|`",      flags: ["codeSpan"]},
                {tag: "code block",                input: "```|B|```",  flags: ["codeBlock"]},
                // Nested layers: each matched delimiter run inward contributes its own flag.
                {tag: "strikethrough wrapping bold", input: "~~**|A|**~~", flags: ["strikethrough", "bold"]},
                {tag: "bold wrapping strikethrough", input: "**~~|A|~~**", flags: ["bold", "strikethrough"]},
                {tag: "strike/bold/italic nested",   input: "~~***|A|***~~", flags: ["strikethrough", "bold", "italic"]},
                // Crossed (not nested): the same char is matched on the other end regardless of
                // position, so both flags are still reported.
                {tag: "crossed strike/bold",         input: "~~**|A|~~**", flags: ["strikethrough", "bold"]},
                {tag: "crossed bold/strike",         input: "**~~|A|**~~", flags: ["bold", "strikethrough"]},
                // Lone leading "*" split off by a backtick isn't part of the "**" pair; "**"+"*" on
                // each end still resolve to bold and italic.
                {tag: "bold+italic across backtick",  input: "*`**|A|***", flags: ["bold", "italic"]},
                // Consuming "**" must not make the two separated "~" adjacent: no "~~" on the left,
                // so strikethrough is not reported — only bold.
                {tag: "split tildes, bold only",      input: "~**~|A|~~**", flags: ["bold"]},
                // Selection edges are just content; only the expanded outer ends decide the flags.
                {tag: "inner delim, outer italic", input: "B *|~B|`*F", flags: ["italic"]},
                {tag: "left edge merges, no right", input: "B *|*D**E|", flags: []},
                {tag: "right edge merges into **",  input: "**|B**|",   flags: ["bold"]},
                {tag: "no delimiters",             input: "x|B|y",      flags: []},
                {tag: "only one side",             input: "**|B|",      flags: []},
                // quote: true when every partially-selected line starts with "> ".
                {tag: "quote, single line",        input: "> A |B| C",         flags: ["quote"]},
                {tag: "quote, both lines quoted",  input: "> A | C\n> D |",    flags: ["quote"]},
                {tag: "quote false, plain 2nd line", input: "> A | B\nC|",     flags: []},
                {tag: "quote + bold",              input: "> **|B|**",         flags: ["bold", "quote"]},
            ]
        }

        function test_delimitersAtSelection(data) {
            const first = data.input.indexOf("|")
            const second = data.input.indexOf("|", first + 1)
            control.text = data.input.replace(/\|/g, "")
            const selectionStart = first
            const selectionEnd = second - 1 // removing the first "|" shifts the second left by one

            const fields = ["bold", "italic", "strikethrough", "codeSpan", "codeBlock", "quote"]
            const m = control.delimitersAtSelection(selectionStart, selectionEnd)
            fields.forEach(f => compare(m[f], data.flags.indexOf(f) !== -1,
                                        f + " for \"" + data.input + "\""))
        }

        // ── removeDelimitersAt: strip the delimiter chars a given kind accounts for ──────

        // Symmetrical to delimitersAt, but parametrized by kind so stacked emphasis is unambiguous:
        // from "***|***", italic strips one "*" each side, bold strips two. Non-stacking kinds strip
        // the whole run. A no-op when the kind is not present around the caret.
        function test_removeDelimitersAt_data() {
            return [
                {tag: "bold",                     input: "**|**",               kind: "bold",          output: "|"},
                {tag: "italic",                   input: "A *|*",               kind: "italic",        output: "A |"},
                {tag: "italic from ***",          input: "***|***",             kind: "italic",        output: "**|**"},
                {tag: "bold from ***",            input: "***|***",             kind: "bold",          output: "*|*"},
                {tag: "italic no-op on ** (even)", input: "**|**",              kind: "italic",        output: "**|**"},
                {tag: "bold no-op on * (single)", input: "*|*",                 kind: "bold",          output: "*|*"},
                {tag: "strikethrough",            input: "~~|~~",               kind: "strikethrough", output: "|"},
                {tag: "strikethrough, 3 tildes",  input: "~~~|~~~",             kind: "strikethrough", output: "|"},
                {tag: "code span, 1 backtick",    input: "some `|`",            kind: "codeSpan",      output: "some |"},
                {tag: "code span, 2 backticks",   input: "``|``",               kind: "codeSpan",      output: "|"},
                {tag: "code block, 3 backticks",  input: "some ```|```",        kind: "codeBlock",     output: "some |"},
                {tag: "codeSpan no-op on ```",    input: "```|```",             kind: "codeSpan",      output: "```|```"},
                {tag: "codeBlock no-op on `",     input: "`|`",                 kind: "codeBlock",     output: "`|`"},
                {tag: "local only, ignores ctx",  input: "```code *|* code```", kind: "italic",        output: "```code | code```"},
                {tag: "single tilde (no-op)",     input: "~|~",                 kind: "strikethrough", output: "~|~"},
                {tag: "mismatched (no-op)",       input: "*|~",                 kind: "italic",        output: "*|~"},
                {tag: "not a delimiter (no-op)",  input: "ab|cd",               kind: "bold",          output: "ab|cd"},
                {tag: "at start (no-op)",         input: "|**bold**",           kind: "bold",          output: "|**bold**"},
                {tag: "wrong kind (no-op)",       input: "**|**",               kind: "codeSpan",      output: "**|**"},
            ]
        }

        function test_removeDelimitersAt(data) {
            const position = data.input.indexOf("|")
            control.text = data.input.replace("|", "")
            control.cursorPosition = position

            control.removeDelimitersAt(position, data.kind)

            compare(control.text, data.output.replace("|", ""))
            compare(control.cursorPosition, data.output.indexOf("|"))
        }

        // The strip is a single edit block: one undo restores the whole run at once.
        function test_removeDelimitersAt_singleUndo() {
            control.text = "x****y"
            control.cursorPosition = 3 // enclosed by the "**" pair on each side

            control.removeDelimitersAt(3, "bold")
            compare(control.text, "xy")

            control.undo()
            compare(control.text, "x****y")
        }
    }
}
