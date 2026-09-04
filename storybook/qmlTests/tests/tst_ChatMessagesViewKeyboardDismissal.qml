import QtQuick
import QtTest

import utils

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Tapping or dragging the transcript dismisses the on-screen keyboard
 (issue #21743). A desktop test host has no panel for
 Qt.inputMethod.hide() to retract, so what is pinned here is the gesture
 wiring: the tap reaches the handler over the message list and does not
 consume, and the drag gate discriminates a user drag from the programmatic
 scrolls this view performs on every incoming message.
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }

    ListModel { id: messagesModel }

    QtObject {
        id: contentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool active: true
            readonly property bool highlight: false
            readonly property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: messagesModel
            property bool loading: false
            property bool keepUnread: false

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)

            function getChatId() { return "chat-1" }
            function loadMoreMessages() {}
            function updateKeepUnread(flag) {}
        }

        function markAllMessagesRead() {}
        function getMyChatId() { return "chat-1" }
        function amIChatAdmin() { return false }
    }

    Component {
        id: contentViewComp

        ChatContentView {
            width: 800
            height: 600

            rootStore: rootStoreMock
            chatContentModule: contentModuleMock
            chatId: "chat-1"
            chatType: Constants.chatType.oneToOne
            usersModel: ListModel {}
            joined: true
        }
    }

    // Stand-ins for the real transcript rows, which all take the exclusive grab
    // on press: message text is a selectable TextEdit, avatars, media and
    // stickers carry MouseAreas, and the message header has its own TapHandler.
    Component {
        id: grabbingMouseAreaComp

        MouseArea {
            property int clicks: 0

            anchors.fill: parent
            onClicked: clicks++
        }
    }

    Component {
        id: selectableTextComp

        TextEdit {
            anchors.fill: parent
            text: "a selectable message body"
            readOnly: true
            selectByMouse: true
        }
    }

    SignalSpy {
        id: activationSpy
        signalName: "activeChanged"
    }

    SignalSpy {
        id: draggingSpy
        signalName: "draggingChanged"
    }

    TestCase {
        name: "ChatMessagesViewKeyboardDismissal"
        when: windowShown

        function cleanup() {
            activationSpy.clear()
            activationSpy.target = null
            draggingSpy.clear()
            draggingSpy.target = null
            messagesModel.clear()
        }

        function dismisserOf(item) {
            return findChild(item, "dismissKeyboardHandler")
        }

        function createTranscript() {
            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)
            const messagesView = view.chatMessagesLoader.item
            verify(!!messagesView)
            tryVerify(() => messagesView.visible && messagesView.width > 0)
            return messagesView
        }

        // The handler has to sit on the list, not on an ancestor: a flickable
        // accepts the press itself and delivery stops before reaching an
        // ancestor's handlers, so a transcript tap would never be seen.
        function test_tapOverTheMessageListReachesTheHandler() {
            const messagesView = createTranscript()
            const handler = dismisserOf(messagesView.chatLogView)
            verify(!!handler, "the message list must carry the dismissal handler")

            activationSpy.target = handler
            mouseClick(messagesView, messagesView.width / 2, messagesView.height / 2)
            compare(activationSpy.count, 2, "one activation on press, one deactivation on release")

            mouseClick(messagesView, messagesView.width / 2, messagesView.height / 2)
            compare(activationSpy.count, 4, "every transcript press must reach the handler")
        }

        function test_programmaticScrollIsNotADrag() {
            const messagesView = createTranscript()
            const chatLogView = messagesView.chatLogView
            const handler = dismisserOf(chatLogView)

            draggingSpy.target = chatLogView
            activationSpy.target = handler

            // the scrolls this view performs on its own: a sent/incoming message
            // and a jump to a quoted message
            contentModuleMock.messagesModule.messageSuccessfullySent()
            chatLogView.positionViewAtBeginning()
            chatLogView.currentIndex = -1

            compare(draggingSpy.count, 0, "programmatic scrolling must not read as a user drag")
            compare(activationSpy.count, 0)
            verify(!chatLogView.dragging)
        }

        function test_userDragTogglesTheDragGate() {
            const messagesView = createTranscript()
            const chatLogView = messagesView.chatLogView
            const handler = dismisserOf(chatLogView)

            // an empty transcript has nothing to scroll under StopAtBounds;
            // allow overshoot so the drag gate can be driven at all
            chatLogView.boundsBehavior = Flickable.DragOverBounds

            draggingSpy.target = chatLogView
            activationSpy.target = handler

            const x = chatLogView.width / 2
            const y0 = chatLogView.height / 2

            mousePress(chatLogView, x, y0)
            for (let y = y0 - 10; y >= y0 - 120; y -= 10)
                mouseMove(chatLogView, x, y)

            verify(chatLogView.dragging, "a user drag must raise the drag gate")
            compare(draggingSpy.count, 1, "the gate must be raised exactly once per drag")

            // the flickable taking over the exclusive grab must neither cancel
            // the dismisser nor make it fire again per move
            verify(handler.active)
            compare(activationSpy.count, 1)

            mouseRelease(chatLogView, x, y0 - 120)

            compare(draggingSpy.count, 2)
            verify(!chatLogView.dragging)
        }

        // The bug behind this file: delivery stops at the topmost item that
        // accepts the press, and practically every transcript row does. The
        // dismisser must still activate, while leaving the row its own click.
        function test_pressOnAGrabbingChildStillReachesTheHandler() {
            const messagesView = createTranscript()
            const chatLogView = messagesView.chatLogView
            const handler = dismisserOf(chatLogView)

            const area = createTemporaryObject(grabbingMouseAreaComp, chatLogView)
            verify(!!area)

            activationSpy.target = handler

            const x = chatLogView.width / 2
            const y = chatLogView.height / 2

            mousePress(chatLogView, x, y)
            verify(handler.active, "an exclusive grab by a child must not cancel the dismisser")
            compare(activationSpy.count, 1, "the dismisser must activate once, and stay activated")

            mouseRelease(chatLogView, x, y)
            compare(area.clicks, 1, "the press must not be consumed: the row keeps its own click")
        }

        function test_pressOnASelectableTextStillReachesTheHandler() {
            const messagesView = createTranscript()
            const chatLogView = messagesView.chatLogView
            const handler = dismisserOf(chatLogView)

            const textEdit = createTemporaryObject(selectableTextComp, chatLogView)
            verify(!!textEdit)

            activationSpy.target = handler

            const x = chatLogView.width / 2
            const y = chatLogView.height / 2

            mousePress(chatLogView, x, y)
            verify(handler.active, "a selectable message body must not cancel the dismisser")
            compare(activationSpy.count, 1)

            mouseRelease(chatLogView, x, y)
            verify(textEdit.activeFocus, "the press must still place the caret in the message body")
        }
    }
}
