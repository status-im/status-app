import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Core.Utils as SQUtils

import shared.status
import utils

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

            StatusChatInput {
                id: editModeInput
                objectName: "editModeInput"

                width: parent.width
                usersModel: ListModel {}
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

    Component {
        id: contactsModelComponent
        ListModel {}
    }

    Component {
        id: imageInputComponent

        StatusChatInput {
            width: 700
            usersModel: ListModel {}
        }
    }

    TestCase {
        name: "StatusChatInput"
        when: windowShown

        property Item wrapperUnderTest: null
        property StatusChatInput controlUnderTest: null

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

        // Replaces the input's users model with a freshly populated one:
        // the suggestions ConcatModel captures roles when a source is set,
        // so rows appended to the initially empty inline model never map.
        function appendContact(displayName) {
            const contacts = contactsModelComponent.createObject(wrapperUnderTest)
            contacts.append({
                pubKey: "0x0" + displayName,
                preferredDisplayName: displayName,
                usesDefaultName: false,
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
            controlUnderTest.usersModel = contacts
        }

        function test_sendButton_icon_data() {
            return [
                { tag: "edit", isEdit: true, iconName: "checkmark" },
                { tag: "regular", isEdit: false, iconName: "arrow-up" },
            ]
        }

        function test_sendButton_icon(data) {
            const toolBar = getToolBar()
            const sendButton = findChild(toolBar, "statusChatInputSendButton")
            verify(!!sendButton)
            controlUnderTest.isEdit = data.isEdit
            compare(sendButton.iconName, data.iconName)
        }

        function test_editMode_toolbarButtons() {
            controlUnderTest.isEdit = true

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

            verify(!toolBar.threadButton.visible)
            verify(!toolBar.threadReplyButton.visible)

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

        // Clicking the mention button inserts the "@" at the caret, not appended to the
        // end of the input. Regression: with the caret moved off the end (e.g. before a
        // code block) the "@" used to land at the very end of the text.
        function test_editMode_mentionButton_insertsAtCaretNotEnd() {
            const toolBar = getToolBar()
            verify(!!toolBar)

            controlUnderTest.textInput.forceActiveFocus()
            typeText("hello world")
            waitForRendering(controlUnderTest)

            controlUnderTest.textInput.cursorPosition = 5 // just after "hello"

            mouseClick(toolBar.mentionButton)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.getPlainText(), "hello@ world")
        }

        // Pressing "@" while the caret is inside a code span must not latch the mention
        // button highlighted: mentions are disabled in code, so the button must stay
        // unchecked and must not get stuck checked when the caret later moves elsewhere.
        function test_editMode_mentionButton_notCheckedInsideCode() {
            const toolBar = getToolBar()
            verify(!!toolBar)

            openFormattingToolbar(toolBar)

            controlUnderTest.textInput.forceActiveFocus()
            toolBar.codeButton.click() // empty caret → inserts a code span, caret inside it
            waitForRendering(controlUnderTest)
            verify(toolBar.codeButton.checked)

            toolBar.mentionButton.click()
            waitForRendering(controlUnderTest)
            verify(!toolBar.mentionButton.checked)

            controlUnderTest.textInput.cursorPosition = 0
            waitForRendering(controlUnderTest)
            verify(!toolBar.mentionButton.checked)
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
            controlUnderTest.isEdit = true

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

        function test_threads_threadButton_send_emitsSendMessageRequestedWithParams_data() {
            return [
                { tag: "empty (default) thread name", explicitThreadName: "" },
                { tag: "explicit thread name", explicitThreadName: "coolThread" },
            ]
        }

        function test_threads_threadButton_send_emitsSendMessageRequestedWithParams() {
            const explicitThreadName = data.explicitThreadName
            controlUnderTest.threadsEnabled = true
            controlUnderTest.isThread = false
            controlUnderTest.chatName = "general"

            const toolBar = getToolBar()
            verify(!!toolBar)
            waitForRendering(toolBar)

            verify(toolBar.threadButton.visible)
            verify(!toolBar.threadReplyButton.visible)
            mouseClick(toolBar.threadButton)
            tryCompare(toolBar.threadButton, "checked", true)

            const threadNameInput = findChild(controlUnderTest, "threadNameInput")
            verify(!!threadNameInput)
            if (explicitThreadName) {
                mouseClick(threadNameInput)
                verify(threadNameInput.activeFocus)
                typeText(explicitThreadName)
                keyClick(Qt.Key_Tab) // move focus back to the main textInput
            }

            tryCompare(controlUnderTest.textInput, "activeFocus", true)
            const msg = "a new thread starts here"
            typeText(msg)
            waitForRendering(controlUnderTest)

            signalSpy.setup(controlUnderTest, "sendMessageRequested")

            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            verify(!!sendButton)
            mouseClick(sendButton)

            compare(signalSpy.count, 1)
            compare(signalSpy.signalArguments[0][0], true) // startNewThread
            compare(signalSpy.signalArguments[0][1], explicitThreadName ? explicitThreadName : msg) // newThreadName (either explicit or deduced from the chat msg)
            compare(signalSpy.signalArguments[0][2], false) // alsoReplyToParentChat
        }

        function test_threads_threadReplyButton_send_emitsSendMessageRequestedWithParams() {
            const threadName = "coolThread"
            const chatName = "general"
            controlUnderTest.threadsEnabled = true
            controlUnderTest.isThread = true
            controlUnderTest.threadName = threadName
            controlUnderTest.chatName = chatName

            const toolBar = getToolBar()
            verify(!!toolBar)

            const threadReplyToChannelInfo = findChild(controlUnderTest, "threadReplyToChannelInfo")
            verify(!!threadReplyToChannelInfo)
            compare(threadReplyToChannelInfo.visible, false)

            // Placeholder be like: Reply in Ξ coolThread
            tryVerify(() => controlUnderTest.chatInputPlaceholder.includes(threadName) && !controlUnderTest.chatInputPlaceholder.includes(chatName))

            signalSpy.setup(controlUnderTest, "sendMessageRequested")

            verify(!toolBar.threadButton.visible)
            verify(toolBar.threadReplyButton.visible)
            mouseClick(toolBar.threadReplyButton)
            compare(toolBar.threadReplyButton.checked, true)

            // Placeholder be like: Reply in Ξ coolThread, also send to #general
            tryVerify(() => controlUnderTest.chatInputPlaceholder.includes(threadName) && controlUnderTest.chatInputPlaceholder.includes(chatName))

            controlUnderTest.textInput.forceActiveFocus()
            typeText("this is a reply in a thread")
            waitForRendering(controlUnderTest)
            compare(threadReplyToChannelInfo.visible, true)

            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            verify(!!sendButton)
            mouseClick(sendButton)

            compare(signalSpy.count, 1)
            compare(signalSpy.signalArguments[0][0], false) // startNewThread
            compare(signalSpy.signalArguments[0][1], "") // newThreadName
            compare(signalSpy.signalArguments[0][2], true) // alsoReplyToParentChat
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

        /*
         Perf guard: profiling showed the mention SuggestionsFilterAdaptor
         sorting the full community members model on every chat switch (669ms
         on a low-end device) although suggestions only matter once the user
         enters a mention. The members model must stay unwired until the first
         mention entry; a loading skeleton covers the wiring window.
        */
        function suggestionList() {
            const list = findChild(controlUnderTest, "suggestionBoxList")
            verify(!!list)
            return list
        }

        function memberSuggestionIndex(displayName) {
            return SQUtils.ModelUtils.indexOf(suggestionList().model,
                                              "pubKey", "0x0" + displayName)
        }

        function test_mentionSuggestions_membersNotMaterializedBeforeEntry() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            compare(memberSuggestionIndex("JohnDoe"), -1,
                    "members must not be materialized before the first mention entry")
        }

        function test_mentionSuggestions_skeletonShownUntilModelWired() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            // hold the wiring so the pre-wire state is observable
            controlUnderTest.suggestionsModelWireDelay = 3600000

            mouseClick(getToolBar().mentionButton)

            const suggestionsBox = findChild(controlUnderTest, "suggestionsBox")
            verify(!!suggestionsBox)
            tryVerify(() => suggestionsBox.visible)

            const skeleton = findChild(suggestionsBox, "suggestionsLoadingSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)
            verify(skeleton.height > 0)
            compare(memberSuggestionIndex("JohnDoe"), -1,
                    "members must not be materialized while the skeleton shows")
        }

        function test_mentionSuggestions_populateOnFirstEntry() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            mouseClick(getToolBar().mentionButton)

            // members appear once the model is wired (after the skeleton
            // window), and the skeleton goes away
            tryVerify(() => memberSuggestionIndex("JohnDoe") >= 0)
            const skeleton = findChild(controlUnderTest, "suggestionsLoadingSkeleton")
            verify(!skeleton || !skeleton.visible)
        }

        // The input instance is shared across chats: a chat switch swaps
        // usersModel on it. A mention entered in one chat must not leave the
        // wiring latched, or every later switch re-sorts the new members
        // model (the 698ms regression seen in the warmstart6 trace).
        function test_mentionSuggestions_modelSwapResetsWiring() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            mouseClick(getToolBar().mentionButton)
            tryVerify(() => memberSuggestionIndex("JohnDoe") >= 0)

            // leave the mention context (as a chat switch does), then swap
            // the model — the next chat's members must stay unmaterialized
            controlUnderTest.textInput.clear()
            waitForRendering(controlUnderTest)
            appendContact("KateRoe")
            waitForRendering(controlUnderTest)

            compare(memberSuggestionIndex("KateRoe"), -1,
                    "swapping usersModel must unwire mention suggestions")

            // a fresh mention entry wires the new model on demand
            mouseClick(getToolBar().mentionButton)
            tryVerify(() => memberSuggestionIndex("KateRoe") >= 0)
        }

        // A model swap while the user is mid-mention (late member delivery,
        // permission re-evaluation) gets no enteringSuggestion edge, so the
        // wiring must re-arm itself or suggestions stay stuck on the skeleton.
        function test_mentionSuggestions_modelSwapMidMentionRearms() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            mouseClick(getToolBar().mentionButton)
            tryVerify(() => memberSuggestionIndex("JohnDoe") >= 0)

            // still in mention-entry mode; swap the model under it
            appendContact("KateRoe")
            tryVerify(() => memberSuggestionIndex("KateRoe") >= 0,
                      5000, "the swapped-in model must wire without leaving mention mode")
        }

        function test_editCancel_emitsSignal() {
            controlUnderTest.isEdit = true
            waitForRendering(controlUnderTest)

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

            // the members model wires into the suggestions shortly after the
            // first mention entry (loading skeleton meanwhile) — a commit
            // only applies to a visible suggestion
            tryVerify(() => memberSuggestionIndex("JohnDoe") >= 0)

            keyClick(Qt.Key_Tab) // commit the highlighted suggestion
            waitForRendering(controlUnderTest)

            verify(!box.visible)
            tryVerify(() => controlUnderTest.getPlainText() === "Hello @0x0JohnDoe ")
        }

        // Typing "@" + a name that matches no user (nor "everyone") must not open a
        // visible-but-empty suggestion box. Otherwise Enter/Send would commit a
        // non-existent row and insert an "@undefined" pill instead of sending;
        // here it must send the text as-is.
        function test_typedMention_noMatchSendsTextAsIs() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            controlUnderTest.textInput.forceActiveFocus()
            typeText("Hello @zzz")
            waitForRendering(controlUnderTest)

            // once the members model wires in, "zzz" matches nothing: the box
            // (a loading skeleton meanwhile) must hide, never sit visible-but-empty
            verify(controlUnderTest.textInput.enteringSuggestion)
            const box = findChild(controlUnderTest, "suggestionsBox")
            verify(!!box)
            tryVerify(() => !box.visible, 5000, "no suggestion box for a non-matching name")

            signalSpy.setup(controlUnderTest, "sendMessageRequested")
            keyClick(Qt.Key_Return) // send (NoModifier maps to send on desktop/offscreen)
            waitForRendering(controlUnderTest)

            verify(!controlUnderTest.getPlainText().includes("@undefined"))
            compare(controlUnderTest.getPlainText(), "Hello @zzz")
            compare(signalSpy.count, 1)
        }

        // Enter inside the wiring window must still send: the box shows only a
        // loading skeleton then — nothing committable — and must not swallow it.
        function test_typedMention_enterDuringLoadingStillSends() {
            appendContact("JohnDoe")
            waitForRendering(controlUnderTest)

            // hold the wiring so the loading window stays open
            controlUnderTest.suggestionsModelWireDelay = 3600000

            controlUnderTest.textInput.forceActiveFocus()
            typeText("Hello @Jo")
            waitForRendering(controlUnderTest)

            const box = findChild(controlUnderTest, "suggestionsBox")
            verify(!!box)
            tryVerify(() => box.visible && box.loading)

            signalSpy.setup(controlUnderTest, "sendMessageRequested")
            keyClick(Qt.Key_Return)
            waitForRendering(controlUnderTest)

            compare(signalSpy.count, 1)
            verify(!controlUnderTest.getPlainText().includes("@undefined"))
        }

        // ── typed emoji-shortcode flow
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

        // A ":" shortcode with no matching emoji must not open an empty suggestion
        // popup. Otherwise Enter is captured as "accept emoji" and deletes the typed text; instead
        // it should send the text as-is.
        function test_typedEmojiShortcode_noMatchSendsTextAsIs() {
            signalSpy.setup(controlUnderTest, "sendMessageRequested")

            controlUnderTest.textInput.forceActiveFocus()
            typeText(":zzzznotanemoji")
            waitForRendering(controlUnderTest)

            // enteringEmoji is true (>= 2 chars after ":"), but there are no matches.
            verify(controlUnderTest.textInput.enteringEmoji)

            keyClick(Qt.Key_Return) // send (NoModifier maps to send on desktop/offscreen)
            waitForRendering(controlUnderTest)

            // The text is preserved (not replaced by an empty-emoji insert) and a send was requested.
            compare(controlUnderTest.getPlainText(), ":zzzznotanemoji")
            compare(signalSpy.count, 1)
        }

        // ── ASCII emoticon conversion
        //
        // A trailing emoticon is converted on send, even though no space completed it.
        function test_asciiEmoticon_convertedOnSend() {
            signalSpy.setup(controlUnderTest, "sendMessageRequested")

            controlUnderTest.textInput.forceActiveFocus()
            typeText("hello :)")
            waitForRendering(controlUnderTest)

            keyClick(Qt.Key_Return) // send (NoModifier maps to send on desktop/offscreen)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.getPlainText(), "hello \u{1F642}")
            compare(signalSpy.count, 1)
        }

        // Typing a space after an emoticon converts it in place.
        function test_asciiEmoticon_convertedOnSpace() {
            controlUnderTest.textInput.forceActiveFocus()
            typeText("hello :) ")
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.getPlainText(), "hello \u{1F642} ")
        }

        function test_selectStickerForTest_emits_stickerSelected() {
            signalSpy.setup(controlUnderTest, "stickerSelected")

            controlUnderTest.selectStickerForTest("hash-abc", "pack-1", "https://example.com/sticker.png")

            compare(signalSpy.count, 1)
            compare(signalSpy.signalArguments[0][0], "hash-abc")
            compare(signalSpy.signalArguments[0][1], "pack-1")
            compare(signalSpy.signalArguments[0][2], "https://example.com/sticker.png")
        }

        // ── Attachment cap
        //
        // Seven distinct PNGs: one over the default per-message cap.
        function sevenImagePaths() {
            const names = ["backup-popup", "qr-scan-success", "status-gradient-dot", "status-logo-circle",
                           "status-logo-dev-circle", "status-logo-icon", "status-logo"]
            return names.map(n => Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/" + n + ".png")
                                    .toString().slice("file://".length))
        }

        function test_imageCap_defaultKeepsMaxUploadFiles() {
            const input = createTemporaryObject(imageInputComponent, root)
            waitForRendering(input)
            compare(input.maxImages, Constants.maxUploadFiles)

            input.validateImagesAndShowImageArea(sevenImagePaths())
            tryCompare(input.fileUrlsAndSources, "length", Constants.maxUploadFiles)
        }

        function test_imageCap_zeroMeansUnlimited() {
            const input = createTemporaryObject(imageInputComponent, root, { maxImages: 0 })
            waitForRendering(input)

            input.validateImagesAndShowImageArea(sevenImagePaths())
            tryCompare(input.fileUrlsAndSources, "length", 7)
        }
    }
}
