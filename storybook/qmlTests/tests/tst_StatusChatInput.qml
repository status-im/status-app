import QtQuick
import QtQuick.Controls
import QtQml
import QtTest

import StatusQ.Core.Utils as SQUtils

import utils
import shared.status

import AppLayouts.Chat.stores as ChatStores

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        StatusChatInput {
            width: parent.width
            height: implicitHeight
            anchors.bottom: parent.bottom
            usersModel: ListModel {}
        }
    }

    QtObject {
        id: testData
        readonly property var multiLineText: ["Typing on first row", "Typing on the second row", "Typing on the third row"]
    }

    TestCase {
        name: "StatusChatInputInitialization"
        when: windowShown

        property StatusChatInput controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        //Scenario: StatusChatInput initialisation
        //Given a new instance of StatusChatInput
        //When there is no keyboard input
        //Then the StatucChatInput raw text is empty
        //But the StatusChatInput is configured to support Rich Text
        function test_empty_chat_input() {
            verify(controlUnderTest.textInput.length == 0, `Expected 0 text length, received: ${controlUnderTest.textInput.length}`)
            verify(controlUnderTest.getPlainText() == "", `Expected empty string, received: ${controlUnderTest.getPlainText()}`)
            verify(controlUnderTest.textInput.textFormat == TextEdit.RichText, "Expected text input format to be Rich")
            verify(controlUnderTest.textInput.text.startsWith("<!DOCTYPE HTML PUBLIC"), "Expected text input format to be Rich")
        }
    }

    TestCase {
        id: statusChatInputKeyboardInputExpectedAsText
        name: "StatusChatInputKeyboardInputExpectedAsText"
        when: windowShown

        property StatusChatInput controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        //Scenario: StatusChatInput will display any typed Ascii visible character
        //Given a new instance of StatusChatInput
        //When the user is typing any Ascii visible character as <text>
        //Then the text is displayed as it is typed
        //And the input text is not modified by mentions processor
        //And the input text is not modified by emoji processor
        //
        //Example:
        //text
        //(!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~)
        function test_keyboard_any_ascii_input() {
            var expectations_after_typed_text = (typedText) => {
                verify(controlUnderTest.getPlainText() === typedText,
                                           `Expected text: ${typedText}, received: ${controlUnderTest.getPlainText()}`)
                verify(controlUnderTest.textInput.text === controlUnderTest.getTextWithPublicKeys(),
                                            `Expected text: ${controlUnderTest.textInput.text}, received: ${controlUnderTest.getTextWithPublicKeys()}`)
            }

            testHelper.when_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                          testHelper.get_all_ascii_characters(),
                                          expectations_after_typed_text);
        }

//        Scenario outline: User can navigate in chat input using keyboard
//        Given the user has typed text on multiple lines in StatusChatInput
//        """
//        Typing on first row
//        Typing on the second row
//        Typing on the third row
//
//        """
//        When the user hits <direction>
//        The cursor will move inside the text area to the <direction>
//
//        Examples:
//        |direction|
//        |left|
//        |right|
//        |up|
//        |down|

//        When the user hits "left"
//        The cursor will move inside the text area to the "left"
//        When the user hits "right"
//        The cursor will move inside the text area to the "right"
//        When the user hits "up"
//        The cursor will move "up" inside the text area, on the previous line if any
//        When the user hits "down"
//        The cursor will move "down" inside the text area, on the next line if any
        function test_user_can_navigate_with_keys() {

            var expect_row_to_be_added = (rowNb) => {
                const expectedText = testData.multiLineText.slice(0, rowNb).join("\n") + "\n"

                compare(controlUnderTest.getPlainText(), expectedText)
                compare(controlUnderTest.textInput.lineCount, rowNb + 1)
            }

            testHelper.when_multiline_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                                    testData.multiLineText,
                                                    expect_row_to_be_added,
                                                    (typedRowText) => {})

            compare(controlUnderTest.textInput.cursorPosition,
                    controlUnderTest.textInput.length,
                    "Expected cursor position at the end of text")

            keyClick(Qt.Key_Right)
            compare(controlUnderTest.textInput.cursorPosition,
                    controlUnderTest.textInput.length,
                    "Expected cursor not to move as we already are at the end of text")

            keyClick(Qt.Key_Left)
            compare(controlUnderTest.textInput.cursorPosition,
                    controlUnderTest.textInput.length - 1,
                    "Expected cursor to move left")

            keyClick(Qt.Key_Up)
            compare(controlUnderTest.textInput.cursorPosition, 42,
                    "Expected cursor to be on the on the second row, two chars from the end")

            keyClick(Qt.Key_Up)
            compare(controlUnderTest.textInput.cursorPosition, 19,
                    "Expected cursor to be on the on end of the first line")

            keyClick(Qt.Key_Down)
            compare(controlUnderTest.textInput.cursorPosition,
                    42,
                    "Expected cursor to be back on the second row, two chars from the end")

            keyClick(Qt.Key_Down)
            compare(controlUnderTest.textInput.cursorPosition,
                    controlUnderTest.textInput.length - 1,
                    "Expected cursor to be back at the end of second line")

            keyClick(Qt.Key_Down)
            compare(controlUnderTest.textInput.cursorPosition,
                    controlUnderTest.textInput.length,
                    "Expected cursor to be back at the end of text")
        }

//        Scenario: User can select text using keyboard
//        Given the user has typed text on multiple lines in StatusChatInput
//        """
//        Typing on first row
//        Typing on the second row
//        Typing on the third row

//        """
//        When the user holds shift key
//        When the user hits <direction>
//        The cursor will move inside the text area to the <direction>
//        And the selected text will be <selectedText>

//        Examples:
//        |direction| selectedText    |
//        |right|     "" |
//        |left|      "\u2028" |
//        |up|        "ow\u2028Typing on the third row\u2028" |
//        |down|      "\u2028" |
        function test_user_can_select_text() {

            testHelper.given_multiline_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                                    testData.multiLineText)

            keyClick(Qt.Key_Right, Qt.ShiftModifier)
            compare(controlUnderTest.textInput.selectedText, "", "No selection expected")

            keyClick(Qt.Key_Left, Qt.ShiftModifier)
            compare(controlUnderTest.textInput.selectedText, "\u2028", "Expected line separator.")

            keyClick(Qt.Key_Up, Qt.ShiftModifier)
            compare(controlUnderTest.textInput.selectedText, "ow\u2028Typing on the third row\u2028")

            keyClick(Qt.Key_Down, Qt.ShiftModifier)
            compare(controlUnderTest.textInput.selectedText, "\u2028", "Expected line separator.")
        }

//        Scenario: The user can select all text in StatusChatInput
//        Given the user has typed text in StatusChatInput
//        """
//        Typing on first row
//        Typing on the second row
//        Typing on the third row

//        """
//        When the user hits select all shortcut
//        Then all the text is selected
        function test_user_can_select_all_text() {
            testHelper.given_multiline_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                                    testData.multiLineText)

            keySequence(StandardKey.SelectAll)
            compare(controlUnderTest.textInput.selectedText, testData.multiLineText.join("\u2028") + "\u2028")
        }

//        Scenario: The user can cut text in StatusChatInput
//        Given the user has selected all text in StatusChatInput
//        """
//        Typing on first row
//        Typing on the second row
//        Typing on the third row

//        """
//        When the user hits cut shortcut
//        Then all selected text is removed
//        And his clipboard contains the initially selected text
        function test_user_can_cut_text() {
            testHelper.given_multiline_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                                    testData.multiLineText)

            keySequence(StandardKey.SelectAll)
            keySequence(StandardKey.Cut)
            compare(controlUnderTest.getPlainText(), "")

            keySequence(StandardKey.Paste)
            compare(controlUnderTest.getPlainText(), testData.multiLineText.join("\n") + "\n")
        }


//        Given the user has contact JohnDoe
//        And the user types a message "Hello @JohnDoe!"
//        Then the user can mention his contact as @JohnDoe
//        And mentions suggestions openes when "@" is typed
//        And the mentions suggestions will contain @JohnDoe as the mention is typed
//        And the mentions suggestions will close once "e" is typed
//        And the mention is sepparated by the next input once the mention is added to TextArea
//        And the contact name from the mention can be replaced with "'0x0JohnDoe'" public key
        function test_keyboard_mentions_input() {
            skip("Sometimes the mentions suggestions is not visible.")
            testHelper.when_the_user_has_contact(controlUnderTest, "JohnDoe", (contact) => {
                        verify(controlUnderTest.usersStore.usersModel.count == 1, `Expected user to have 1 contact`)
                    })

            let expect_visible_suggestions_on_mention_typing = (typedText) => {
                if(typedText.startsWith("Hello @") && !typedText.startsWith("Hello @JohnDoe")) {
                     verify(controlUnderTest.suggestions.visible == true,
                       `Expected the mention suggestions to be visible`)

                     verify(controlUnderTest.suggestions.listView.currentItem.objectName === "JohnDoe",
                       `Expected the mention suggestions current item to be JohnDoe, received ${controlUnderTest.suggestions.listView.currentItem.objectName}`)
                 }
            }

            testHelper.when_text_is_typed(statusChatInputKeyboardInputExpectedAsText,
                                          "Hello @JohnDoe!", expect_visible_suggestions_on_mention_typing)

            verify(controlUnderTest.suggestions.visible == false,
                   `Expected the mention suggestions to be closed`)

            compare(controlUnderTest.getPlainText(),
                    "Hello \[\[mention\]\]@JohnDoe\[\[mention\]\] !",
                    "Expected the mention to be inserted")

            var textWithPubKey = controlUnderTest.getTextWithPublicKeys()
            verify(textWithPubKey.includes("@0x0JohnDoe"),
                   "Expected @pubKey to replace @contactName")
        }
    }

    TestCase {
        id: statusChatInputStandardKeySequence
        name: "StatusChatInputStandardKeySequence"
        when: windowShown

        property var controlUnderTest: null
        property TextArea standardInput: null

        Component {
            id: standardTextAreaComponent
            TextArea {
                width: 400
                height: 100
                textFormat: Qt.RichText
                selectByMouse: true
            }
        }

//        Scenario: Default TextArea keyboard shortcuts are not altered by StatusChatInput
//        Given a new StatusChatInput instance
//        And a new standard Qt TextArea instance
//        When the user is typing multiline text
//        """
//        Typing on first row
//        Typing on the second row
//        Typing on the third row

//        """
//        And is using standard key shortcutss
//        Then the StatusChatInput will behave as standard TextArea
        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            standardInput = createTemporaryObject(standardTextAreaComponent, root)

            standardInput.forceActiveFocus()
            testHelper.given_multiline_text_is_typed(statusChatInputStandardKeySequence, testData.multiLineText)

            controlUnderTest.textInput.forceActiveFocus()
            testHelper.given_multiline_text_is_typed(statusChatInputStandardKeySequence, testData.multiLineText)

        }

        function test_standard_key_shortcuts_data() {
            return [
                         { tag: "Delete", key: StandardKey.Delete, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "Undo", key: StandardKey.Undo, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "Redo", key: StandardKey.Redo, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true  },
                         { tag: "SelectAll", key: StandardKey.SelectAll, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0  , expectIdenticalPlainText: true },
                         { tag: "Bold", key: StandardKey.Bold, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 3, expectIdenticalPlainText: false, expectIdenticalSelection: false  },
                         { tag: "Italic", key: StandardKey.Italic, initialCursorPosition: 0, initialSelectionStart: 8, initialSelectionEnd: 10, expectIdenticalPlainText: false, expectIdenticalSelection: false  },
                         { tag: "MoveToNextChar", key: StandardKey.MoveToNextChar, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToPreviousChar", key: StandardKey.MoveToPreviousChar, initialCursorPosition: 5, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToNextWord", key: StandardKey.MoveToNextWord, initialCursorPosition: 2, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true},
                         { tag: "MoveToPreviousWord", key: StandardKey.MoveToPreviousWord, initialCursorPosition: 15, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true},
                         { tag: "MoveToNextLine", key: StandardKey.MoveToNextLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true},
                         { tag: "MoveToPreviousLine", key: StandardKey.MoveToPreviousLine, initialCursorPosition: 30, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true},
                         { tag: "MoveToStartOfLine", key: StandardKey.MoveToStartOfLine, initialCursorPosition: 10, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToEndOfLine", key: StandardKey.MoveToEndOfLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToStartOfBlock", key: StandardKey.MoveToStartOfBlock, initialCursorPosition: 40, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToEndOfBlock", key: StandardKey.MoveToEndOfBlock, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToStartOfDocument", key: StandardKey.MoveToStartOfDocument, initialCursorPosition: 40, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "MoveToEndOfDocument", key: StandardKey.MoveToEndOfDocument, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectNextChar", key: StandardKey.SelectNextChar, initialCursorPosition: 5, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectPreviousChar", key: StandardKey.SelectPreviousChar, initialCursorPosition: 5, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectNextWord", key: StandardKey.SelectNextWord, initialCursorPosition: 2, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectPreviousWord", key: StandardKey.SelectPreviousWord, initialCursorPosition: 15, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectNextLine", key: StandardKey.SelectNextLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectPreviousLine", key: StandardKey.SelectPreviousLine, initialCursorPosition: 30, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectStartOfLine", key: StandardKey.SelectStartOfLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectEndOfLine", key: StandardKey.SelectEndOfLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectStartOfBlock", key: StandardKey.SelectStartOfBlock, initialCursorPosition: 40, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectEndOfBlock", key: StandardKey.SelectEndOfBlock, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectStartOfDocument", key: StandardKey.SelectStartOfDocument, initialCursorPosition: 40, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "SelectEndOfDocument", key: StandardKey.SelectEndOfDocument, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "DeleteStartOfWord", key: StandardKey.DeleteStartOfWord, initialCursorPosition: 4, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "DeleteEndOfWord", key: StandardKey.DeleteEndOfWord, initialCursorPosition: 4, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "DeleteEndOfLine", key: StandardKey.DeleteEndOfLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "InsertLineSeparator", key: StandardKey.InsertLineSeparator, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "Deselect", key: StandardKey.Deselect, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 10, expectIdenticalPlainText: true },
                         { tag: "DeleteCompleteLine", key: StandardKey.DeleteCompleteLine, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "Backspace", key: StandardKey.Backspace, initialCursorPosition: 5, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true },
                         { tag: "AddTab", key: StandardKey.AddTab, initialCursorPosition: 0, initialSelectionStart: 0, initialSelectionEnd: 0, expectIdenticalPlainText: true }
            ]
        }

        function test_standard_key_shortcuts(data) {

            standardInput.forceActiveFocus()
            standardInput.cursorPosition = data.initialCursorPosition
            standardInput.select(data.initialSelectionStart, data.initialSelectionEnd)

            keySequence(data.key)
            let standardControlSelection = standardInput.selectedText
            let standardControlCursorPosition = standardInput.cursorPosition

            controlUnderTest.textInput.forceActiveFocus()
            controlUnderTest.textInput.cursorPosition = data.initialCursorPosition
            controlUnderTest.textInput.select(data.initialSelectionStart, data.initialSelectionEnd)

            keySequence(data.key)
            let controlUnderTestSelection = controlUnderTest.textInput.selectedText
            let controlUnderTestCursorPosition = controlUnderTest.textInput.cursorPosition

            if(data.expectIdenticalPlainText) {
                compare(controlUnderTest.textInput.length, standardInput.length, "Expected identical text length")
                compare(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length),
                        standardInput.getText(0, standardInput.length),
                        "Expected identical text")
                compare(controlUnderTestCursorPosition, standardControlCursorPosition, "Expected identical cursor position")
                compare(controlUnderTestSelection, standardControlSelection, "Expected identical selected text")
            } else {
                //the text is expected to be different due to custom processor
                //Ex: bold or italic where text is wrapped in specific symbols
                verify(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length) !==
                       standardInput.getText(0, standardInput.length),
                       "Expected different text")
            }
        }
    }

    TestCase {
        id: statusChatInputEmojiAndMentions
        name: "StatusChatInputEmojiAndMentions"
        when: windowShown

        property StatusChatInput controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

//        Scenario: The user can type text, mention and emoji
//        Given a new instance of StatusChatInput
//        And the user has  <mention> as contact
//        When the user is typing <text>
//        Then the text is displayed in the input field as <expectedText>
//        And the <mention> is inserted in the input field
//        And the <emoji> is inserted in the input field
//        And the <mention> can be replaced with contact public key

//        Examples:
//        text                              | mention              	| expectedPlainText
//        “Hello John:D”                    |                       | “Hello John\uD83D\uDE04“
//        “Hello @JohnDoe”                  | @JohnDoe				| “Hello @JohnDoe ”
//        “Hello:D@JohnDoe“                 | @JohnDoe				| “Hello\uD83D\uDE04 @JohnDoe “
//        “:DHello@JohnDoe”                 | @JohnDoe 				| “\uD83D\uDE04 Hello @JohnDoe ”
//        “:D:D:D:D:D:D@JohnDoe:D:D:D”		| @JohnDoe				| “\uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 @JohnDoe \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 ”
//        “Hello:@JohnDoe1:D@JohnDoe2:D 	| @JohnDoe1 @JohnDoe2	| “Hello:@JohnDoe1 \uD83D\uDE04 @JohnDoe2 \uD83D\uDE04 ”
//        “Hello:@JohnDoe1:D@JohnDoe2:D 	|                       | “Hello:@JohnDoe1\uD83D\uDE04 @JohnDoe2\uD83D\uDE04 ”
        function test_text_mention_emoji_input_data() {
            return [
                { tag: "Hello John:D", text: "Hello John :D ", mention: [], expectedText: "Hello John \uD83D\uDE04 " },
                { tag: "Hello @JohnDoe", text: "Hello @JohnDoe", mention: ["JohnDoe"], expectedText: "Hello @JohnDoe " },
                { tag: "Hello:D@JohnDoe", text: "Hello :D @JohnDoe", mention: ["JohnDoe"], expectedText: "Hello \uD83D\uDE04 @JohnDoe " },
                { tag: ":DHello@JohnDoe", text: ":D Hello@JohnDoe", mention: ["JohnDoe"], expectedText: "\uD83D\uDE04 Hello@JohnDoe " },
                { tag: ":D :D :D :D :D :D @JohnDoe:D :D :D ", text: ":D :D :D :D :D :D @JohnDoe:D :D :D ", mention: ["JohnDoe"], expectedText: "\uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 @JohnDoe \uD83D\uDE04 \uD83D\uDE04 \uD83D\uDE04 " },
                { tag: "Hello:@JohnDoe1:D@JohnDoe2:D with contact", text: "Hello @JohnDoe1:D @JohnDoe2:D ", mention: ["JohnDoe1", "JohnDoe2"], expectedText: "Hello @JohnDoe1 \uD83D\uDE04 @JohnDoe2 \uD83D\uDE04 " },
                { tag: "Hello:@JohnDoe1:D@JohnDoe2:D without contact", text: "Hello @JohnDoe1 :D @JohnDoe2 :D ", mention: [], expectedText: "Hello @JohnDoe1 \uD83D\uDE04 @JohnDoe2 \uD83D\uDE04 " },
            ]
        }

        function test_text_mention_emoji_input(data) {
            skip("Unreliable test. Fails randomly")
            data.mention.forEach(contact => testHelper.when_the_user_has_contact(controlUnderTest, contact, (addedContact) => {}))
            testHelper.when_text_is_typed(statusChatInputEmojiAndMentions,
                                          data.text, (typedText) => { keyClick(Qt.Key_Shift) /*mentions will be inserted only after a key input*/})
            var plainText = controlUnderTest.removeMentions(controlUnderTest.getPlainText())

            compare(plainText,
                    data.expectedText)
        }
    }

    TestCase {
        id: statusChatInputMentions
        name: "StatusChatInputMentions"
        when: windowShown

        property StatusChatInput controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        //Scenario: Mention behaves like a single character when moving cursor by keyboard
        //Given the user has contact <mention>
        //And typed message <textInput>
        //And has placed cursor at mention <initialPosition>
        //When the user hits <key>
        //The cursor moves to <expectedPosition>
        //Example:
        //| textInput       | mention | initialPosition | key   | expectedPosition |
        //| Hello @JohnDoe! |         | 6               | right | 7                |
        //| Hello @JohnDoe! |         | 14              | left  | 13               |
        //| Hello @JohnDoe! | JohnDoe | 6               | right | 14               |
        //| Hello @JohnDoe! | JohnDoe | 14              | left  | 6                |
        function test_mention_is_skipped_by_cursor_data() {
            return [
                        {tag: "MoveRightNoMention", textInput: "Hello @JohnDoe!", mention: "", initialPosition: 6, key: Qt.Key_Right, expectedPosition: 7},
                        {tag: "MoveLeftNoMention", textInput: "Hello @JohnDoe!", mention: "", initialPosition: 14, key: Qt.Key_Left, expectedPosition: 13},
                        {tag: "MoveRightWithMention", textInput: "Hello @JohnDoe!", mention: "JohnDoe", initialPosition: 6, key: Qt.Key_Right, expectedPosition: 14},
                        {tag: "MoveLeftWithMention", textInput: "Hello @JohnDoe!", mention: "JohnDoe", initialPosition: 14, key: Qt.Key_Left, expectedPosition: 6}
                    ]
        }

        function test_mention_is_skipped_by_cursor(data) {
            skip("Unreliable test. Failing randomly")
            if(data.mention !== "") {
                testHelper.when_the_user_has_contact(controlUnderTest, data.mention, (contact) => {})
            }
            testHelper.when_text_is_typed(statusChatInputMentions,
                                          data.textInput, (typedText) => {})
            controlUnderTest.textInput.cursorPosition = data.initialPosition
            compare(controlUnderTest.textInput.cursorPosition, data.initialPosition)

            keyClick(data.key)
            compare(controlUnderTest.textInput.cursorPosition, data.expectedPosition)
        }

        //Scenario: Mention behaves like a single character when selecting by keyboard
        //Given the user has contact <mention>
        //And typed message <textInput>
        //And has placed cursor at mention <initialPosition>
        //When the user hits <key> holding Shift
        //The selected text is <expectedSelection>
        //Example:
        //| textInput       | mention | initialPosition | key   | expectedSelection     |
        //| Hello @JohnDoe! |         | 6               | right | @                     |
        //| Hello @JohnDoe! |         | 14              | left  | e                     |
        //| Hello @JohnDoe! | JohnDoe | 6               | right | @JohnDoe              |
        //| Hello @JohnDoe! | JohnDoe | 14              | left  | @JohnDoe              |
        function test_mention_is_selected_by_keyboard_data() {
            return [
                        {tag: "SelectRightNoMention", textInput: "Hello @JohnDoe!", mention: "", initialPosition: 6, key: Qt.Key_Right, expectedSelection: "@"},
                        {tag: "SelectLeftNoMention", textInput: "Hello @JohnDoe!", mention: "", initialPosition: 14, key: Qt.Key_Left, expectedSelection: "e"},
                        {tag: "SelectRightWithMention", textInput: "Hello @JohnDoe!", mention: "JohnDoe", initialPosition: 6, key: Qt.Key_Right, expectedSelection: "@JohnDoe"},
                        {tag: "SelectLeftWithMention", textInput: "Hello @JohnDoe!", mention: "JohnDoe", initialPosition: 14, key: Qt.Key_Left, expectedSelection: "@JohnDoe"}
                    ]
        }

        function test_mention_is_selected_by_keyboard(data) {
            skip("Unstable test")
            if(data.mention !== "") {
                testHelper.when_the_user_has_contact(controlUnderTest, data.mention, (contact) => {})
            }
            testHelper.when_text_is_typed(statusChatInputMentions,
                                          data.textInput, (typedText) => {})
            controlUnderTest.textInput.cursorPosition = data.initialPosition
            compare(controlUnderTest.textInput.cursorPosition, data.initialPosition)

            keyClick(data.key, Qt.ShiftModifier)
            compare(controlUnderTest.textInput.selectedText, data.expectedSelection)
        }

        //Scenario: Clicking mention will select the mention
        //Given the user has contact JohnDoe
        //And has typed message Hello @JohnDoe!
        //When the user clicks @JohnDoe text
        //Then the text @JohnDoe is selected
        function test_mention_click_is_selecting_mention() {
            skip("Unreliable test. Failing randomly")
            testHelper.when_the_user_has_contact(controlUnderTest, "JohnDoe", (contact) => {})
            testHelper.when_text_is_typed(statusChatInputMentions,
                                          "Hello @JohnDoe!", (typedText) => {})
            controlUnderTest.textInput.cursorPosition = 6
            const cursorRectangle = controlUnderTest.textInput.cursorRectangle

            mouseClick(controlUnderTest.textInput, cursorRectangle.x + 5, controlUnderTest.textInput.height / 2)
            compare(controlUnderTest.textInput.selectedText,
                    "@JohnDoe")
        }

        //Scenario: Mention cannot be invalidated by user actions
        //Given the user has contact JohnDoe
        //And has typed message Hello @JohnDoe!
        //When the user is performing <actions>
        //And hits enter
        //Then the mention is still valid
        //And can be replaced with publicKey
        //Example:
        //|Action|
        //|The space after mention is deleted and mention suggestion is closed key left|
        //|The space after mention is deleted and mention suggestion is closed key "S"|

        function test_mention_cannot_be_invalidated() {
            skip("Test is failing. Mention is invalidated by user actions")
            testHelper.when_the_user_has_contact(controlUnderTest, "JohnDoe", (contact) => {})
            testHelper.when_text_is_typed(statusChatInputMentions,
                                          "Hello @JohnDoe!", (typedText) => {})
            controlUnderTest.textInput.cursorPosition = 15

            keyClick(Qt.Key_Backspace)
            compare(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length), "Hello @JohnDoe!")

            keyClick(Qt.Key_Left)
            compare(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length), "Hello @JohnDoe !")

            var plainTextWithPubKey = SQUtils.StringUtils.plainText(controlUnderTest.getTextWithPublicKeys())
            compare(plainTextWithPubKey, "Hello @0x0JohnDoe !")

            controlUnderTest.textInput.cursorPosition = 15
            keyClick(Qt.Key_Backspace)
            compare(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length), "Hello @JohnDoe!")

            keyClick(Qt.Key_S)
            plainTextWithPubKey = SQUtils.StringUtils.plainText(controlUnderTest.getTextWithPublicKeys())
            compare(plainTextWithPubKey, "Hello @0x0JohnDoe s!")
        }

        //Scenario: User can remove mention by replacing a larger selected text section with a letter
        //Given the user has contact JohnDoe
        //And has typed "Hello @JohnDoe!"
        //And has selected "lo @JohnDoe !"
        //And has typed "s"
        //Then the text is "Hells"
        //And the mention is removed
        function test_mention_is_deleted_with_large_selection() {
            skip("Test is failing. Mention is not selected")
            testHelper.when_the_user_has_contact(controlUnderTest, "JohnDoe", (contact) => {})
            testHelper.when_text_is_typed(statusChatInputMentions,
                                          "Hello @JohnDoe!", (typedText) => {})
            controlUnderTest.textInput.select(3, 16)
            compare(controlUnderTest.textInput.selectedText,
                    "lo @JohnDoe !")

            keyClick(Qt.Key_S)
            compare(controlUnderTest.textInput.getText(0, controlUnderTest.textInput.length),
                    "Hels")

            const plainTextWithPubKey = SQUtils.StringUtils.plainText(controlUnderTest.getTextWithPublicKeys())
            compare(plainTextWithPubKey,
                    "Hels")
        }
    }

    QtObject {
        id: testHelper

        function get_all_ascii_characters() {
            let result = '';
            for( let i = 32; i <= 126; i++ )
            {
                result += String.fromCharCode( i );
            }
            return result
        }

        function when_the_user_has_contact(controlUnderTest: StatusChatInput, contact: string, expectationAfterContactAdded) {
            controlUnderTest.usersStore.usersModel.append({
                   pubKey: `0x0${contact}`,
                   onlineStatus: 1,
                   isContact: true,
                   isVerified: true,
                   isAdmin: false,
                   isUntrustworthy: false,
                   displayName: contact,
                   alias: `${contact}-alias`,
                   localNickname: `${contact}-local-nickname`,
                   ensName: `${contact}.stateofus.eth`,
                   icon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAlklEQVR4nOzW0QmDQBAG4SSkl7SUQlJGCrElq9F3QdjjVhh/5nv3cFhY9vUIYQiNITSG0BhCExPynn1gWf9bx498P7/
                         nzPcxEzGExhBdJGYihtAYQlO+tUZvqrPbqeudo5iJGEJjCE15a3VtodH3q2ImYgiNITTlTdG1nUZ5a92VITQxITFiJmIIjSE0htAYQrMHAAD//+wwFVpz+yqXAAAAAElFTkSuQmCC",
                   colorId: 7
            })
            expectationAfterContactAdded(contact)
        }

        function when_text_is_typed(testCase: TestCase, textInput: string, expectationAfterTextInput) {
            for (let i = 0; i < textInput.length; i++) {
                const typedText = textInput.slice(0,i+1)
                const key = textInput[i];
                testCase.keyClick(key)
                expectationAfterTextInput(typedText)
            }
        }

        function when_multiline_text_is_typed(testCase: TestCase, textLines: list<string>, expectationAfterNewLine, expectationAfterTextInput) {
            for(let i = 0; i < textLines.length; i++) {
                when_text_is_typed(testCase, textLines[i], expectationAfterTextInput)
                testCase.keyClick(Qt.Key_Enter, Qt.ShiftModifier)
                expectationAfterNewLine(i+1)
            }
        }

        function given_multiline_text_is_typed(testCase: TestCase, textLines: list<string>) {
            when_multiline_text_is_typed(testCase, textLines, (lineNb) => {}, (typedText) => {})
        }
    }
}
