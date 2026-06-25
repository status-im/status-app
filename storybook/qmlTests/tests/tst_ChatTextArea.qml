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

        // ── quoteBarVisible ─────────────────────────────────────────────────────

        function test_quoteBarVisible_defaultsTrueAndSettable() {
            compare(control.quoteBarVisible, true)
            control.quoteBarVisible = false
            compare(control.quoteBarVisible, false)
        }
    }
}
