import QtQuick
import QtQuick.Controls
import QtTest

import shared.status

Item {
    id: root
    width: 800
    height: 400

    Component {
        id: gifPickerComponent

        Popup {
            objectName: "testGifPicker"
            modal: false

            required property var gifSelectedCallback
            required property var closeCallback

            width: 120
            height: 60

            Button {
                objectName: "testGifPickerSelectButton"
                anchors.centerIn: parent
                text: "GIF"
                onClicked: {
                    gifSelectedCallback("https://example.com/test.gif")
                    close()
                }
            }

            onClosed: {
                if (closeCallback)
                    closeCallback()
            }
        }
    }

    Component {
        id: editModeComponent
        Item {
            width: 700
            height: 400

            Popup {
                id: emojiPopupStub
                objectName: "emojiPopupStub"
                modal: false
                width: 80
                height: 60

                signal emojiSelected(string emoji, bool atCursor, string hexcode)

                Button {
                    objectName: "emojiPopupSelectButton"
                    anchors.centerIn: parent
                    text: "😀"
                    onClicked: {
                        emojiPopupStub.emojiSelected("😀 ", true, "1f600")
                        emojiPopupStub.close()
                    }
                }
            }

            StatusChatInputNew {
                id: editModeInput
                objectName: "editModeInput"

                width: parent.width
                usersModel: ListModel {}
                isEdit: true
                imageFeaturesEnabled: false
                stickersButtonVisible: false
                paymentRequestButtonVisible: false
                emojiPopup: emojiPopupStub

                onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => {
                    const picker = gifPickerComponent.createObject(parent, {
                        gifSelectedCallback: cbOnGifSelected,
                        closeCallback: cbOnClose
                    })
                    picker.open()
                }
            }
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusChatInputNew"
        when: windowShown

        property Item wrapperUnderTest: null
        property StatusChatInputNew controlUnderTest: null

        function init() {
            wrapperUnderTest = createTemporaryObject(editModeComponent, root)
            controlUnderTest = findChild(wrapperUnderTest, "editModeInput")
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (wrapperUnderTest)
                wrapperUnderTest.destroy()
            wrapperUnderTest = null
            controlUnderTest = null
        }

        function getToolBar() {
            return findChild(controlUnderTest, "statusChatInputToolBar")
        }

        function getInputText() {
            const input = controlUnderTest.textInput
            return input.getText(0, input.length)
        }

        function openFormattingToolbar(toolBar) {
            if (!toolBar.styleButton.checked)
                mouseClick(toolBar.styleButton)
            waitForRendering(controlUnderTest)
            verify(toolBar.styleButton.checked)
        }

        function selectInputText(start, end) {
            controlUnderTest.textInput.forceActiveFocus()
            controlUnderTest.textInput.text = "hello"
            waitForRendering(controlUnderTest)
            controlUnderTest.textInput.select(start, end)
        }

        function appendContact(displayName) {
            controlUnderTest.usersModel.append({
                pubKey: "0x0" + displayName,
                onlineStatus: 1,
                isContact: true,
                isVerified: true,
                isAdmin: false,
                isUntrustworthy: false,
                displayName: displayName,
                preferredDisplayName: displayName,
                alias: displayName + "-alias",
                localNickname: displayName + "-local-nickname",
                ensName: displayName + ".stateofus.eth",
                icon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAlklEQVR4nOzW0QmDQBAG4SSkl7SUQlJGCrElq9F3QdjjVhh/5nv3cFhY9vUIYQiNITSG0BhCExPynn1gWf9bx498P7/nzPcxEzGExhBdJGYihtAYQlO+tUZvqrPbqeudo5iJGEJjCE15a3VtodH3q2ImYgiNITTlTdG1nUZ5a92VITQxITFiJmIIjSE0htAYQrMHAAD//+wwFVpz+yqXAAAAAElFTkSuQmCC",
                colorId: 7
            })
        }

        function test_editMode_toolbarButtons() {
            const toolBar = getToolBar()
            const acceptButton = findChild(controlUnderTest, "statusChatInputEditAcceptButton")
            const cancelButton = findChild(controlUnderTest, "statusChatInputEditCancelButton")
            const closeButton = findChild(controlUnderTest, "statusChatInputEditCloseButton")
            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            const editModeTag = findChild(controlUnderTest, "statusChatInputEditModeTag")

            verify(!!toolBar)
            verify(!!acceptButton)
            verify(!!cancelButton)
            verify(!!closeButton)
            verify(!!sendButton)
            verify(!!editModeTag)

            verify(toolBar.styleButton.visible)
            verify(toolBar.mentionButton.visible)
            verify(toolBar.emojiButton.visible)
            verify(toolBar.gifButton.visible)
            verify(!acceptButton.visible)
            verify(!cancelButton.visible)
            verify(closeButton.visible)
            verify(editModeTag.visible)

            verify(!toolBar.imageButton.visible)
            verify(!toolBar.stickersButton.visible)
            verify(!toolBar.tokenButton.visible)
            verify(!toolBar.cameraButton.visible)
            verify(sendButton.visible)
            compare(toolBar.sendButton.iconName, "checkmark")
        }

        function test_editMode_styleButton_showsFormattingButtons() {
            const toolBar = getToolBar()
            verify(!!toolBar)
            verify(!toolBar.styleButton.checked)

            openFormattingToolbar(toolBar)

            verify(toolBar.boldButton.visible)
            verify(toolBar.italicButton.visible)
            verify(toolBar.strikeThroughButton.visible)
            verify(toolBar.quoteButton.visible)
            verify(toolBar.codeButton.visible)
        }

        function test_editMode_formattingButtons_applyFormatting_data() {
            return [
                { tag: "bold", buttonName: "boldButton" },
                { tag: "italic", buttonName: "italicButton" },
                { tag: "strikethrough", buttonName: "strikeThroughButton" },
                { tag: "code", buttonName: "codeButton" },
                { tag: "quote", buttonName: "quoteButton", useQuote: true }
            ]
        }

        function test_editMode_formattingButtons_applyFormatting(data) {
            const toolBar = getToolBar()
            verify(!!toolBar)

            openFormattingToolbar(toolBar)

            if (data.useQuote) {
                controlUnderTest.textInput.forceActiveFocus()
                controlUnderTest.textInput.text = "hello"
                waitForRendering(controlUnderTest)
                controlUnderTest.textInput.select(0, 5)
            } else {
                selectInputText(0, 5)
            }

            verify(controlUnderTest.textInput.selectedText.length > 0)

            // Programmatic click keeps text selection; mouseClick moves focus to the toolbar.
            toolBar[data.buttonName].click()
            waitForRendering(controlUnderTest)

            if (data.useQuote)
                verify(controlUnderTest.getPlainText().includes("> "))
            else
                verify(toolBar[data.buttonName].checked)
        }

        function test_editMode_mentionButton_opensSuggestions() {
            const toolBar = getToolBar()
            verify(!!toolBar)

            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            mouseClick(toolBar.mentionButton)
            waitForRendering(controlUnderTest)

            const suggestionsBox = findChild(controlUnderTest, "suggestionsBox")
            verify(!!suggestionsBox)
            verify(suggestionsBox.visible)
            verify(controlUnderTest.getPlainText().includes("@"))
        }

        function test_editMode_emojiButton_opensPopupAndSelectsEmoji() {
            const toolBar = getToolBar()
            verify(!!toolBar)

            mouseClick(toolBar.emojiButton)
            waitForRendering(controlUnderTest)

            const emojiPopup = findChild(wrapperUnderTest, "emojiPopupStub")
            verify(!!emojiPopup)
            verify(emojiPopup.visible)

            mouseClick(findChild(emojiPopup, "emojiPopupSelectButton"))
            waitForRendering(controlUnderTest)

            verify(controlUnderTest.getPlainText().includes("😀"))
            verify(!emojiPopup.visible)
        }

        function test_editMode_gifSelection_doesNotSendMessage() {
            const toolBar = getToolBar()
            verify(!!toolBar)

            mouseClick(toolBar.gifButton)
            waitForRendering(controlUnderTest)

            const picker = findChild(wrapperUnderTest, "testGifPicker")
            verify(!!picker)

            signalSpy.setup(controlUnderTest, "sendMessageRequested")
            mouseClick(findChild(picker, "testGifPickerSelectButton"))
            waitForRendering(controlUnderTest)

            verify(controlUnderTest.getPlainText().includes("https://example.com/test.gif"))
            compare(signalSpy.count, 0)
        }

        function test_editMode_sendButton_emitsSendMessageRequested() {
            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            verify(!!sendButton)

            signalSpy.setup(controlUnderTest, "sendMessageRequested")

            controlUnderTest.textInput.text = "hello"
            waitForRendering(controlUnderTest)
            mouseClick(sendButton)

            compare(signalSpy.count, 1)
        }

        function test_editCancel_emitsSignal() {
            const cancelButton = findChild(controlUnderTest, "statusChatInputEditCloseButton")
            verify(!!cancelButton)

            signalSpy.setup(controlUnderTest, "editCancelRequested")
            mouseClick(cancelButton)

            compare(signalSpy.count, 1)
        }

        function typeText(str) {
            for (let i = 0; i < str.length; i++)
                keyClick(str[i])
        }

        // ── typed mention flow

        // Typing "@" opens the suggestion box, filtered live by ChatTextArea's mentionsFilter.
        // Committing the highlighted suggestion (Tab) replaces the typed "@filter" with a mention
        // pill that serializes to the contact's pub key.
        function test_typedMention_opensSuggestionsAndCommits() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            controlUnderTest.textInput.forceActiveFocus()
            typeText("Hello @Jo")
            waitForRendering(controlUnderTest)

            const box = findChild(controlUnderTest, "suggestionsBox")
            verify(!!box)
            verify(box.visible)
            compare(controlUnderTest.textInput.mentionsFilter, "Jo")
            verify(controlUnderTest.getPlainText().includes("@Jo"))

            keyClick(Qt.Key_Tab) // commit the highlighted suggestion
            waitForRendering(controlUnderTest)

            verify(!box.visible)
            tryVerify(() => controlUnderTest.getPlainText() === "Hello @0x0JohnDoe ")
        }

        // ── typed emoji-shortcode flow (migrated from tst_StatusChatInput, re-enabled) ──
        //
        // Typing ":" + a shortcode makes ChatTextArea report enteringEmoji/emojiFilter, which
        // drives the emoji suggestion popup. Committing (Tab) replaces the shortcode with the emoji.
        function test_typedEmojiShortcode_insertsEmoji() {
            controlUnderTest.textInput.forceActiveFocus()
            typeText(":grin")
            waitForRendering(controlUnderTest)

            verify(controlUnderTest.textInput.enteringEmoji)
            compare(controlUnderTest.textInput.emojiFilter, "grin")

            keyClick(Qt.Key_Tab) // commit the highlighted emoji suggestion
            tryVerify(() => !controlUnderTest.textInput.enteringEmoji)

            const plain = controlUnderTest.getPlainText()
            verify(!plain.includes(":grin"), "the shortcode was replaced")
            verify(plain.length > 0)
            // Committed to a real emoji: the first code unit is a high surrogate (U+D800..U+DBFF).
            const first = plain.charCodeAt(0)
            verify(first >= 0xD800 && first <= 0xDBFF, "starts with an emoji: " + JSON.stringify(plain))
        }
    }
}
