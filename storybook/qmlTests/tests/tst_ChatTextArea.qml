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
    }
}
