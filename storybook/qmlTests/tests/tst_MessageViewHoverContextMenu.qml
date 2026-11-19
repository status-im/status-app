import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

import shared.status
import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

Item {
    id: root

    readonly property ChatTextAppearance textAppearance: MessageTextAppearance {
        theme: root.Theme
    }
    readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance {
        theme: root.Theme
    }

    width: 800
    height: 600

    ListModel {
        id: contactsModel
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel
    }

    ChatStores.MessageStore {
        id: messageStoreMock
    }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
        }
    }

    // The list a message sits in, as far as hovering is concerned: whether it
    // is moving (a drag or a flick) or gliding to a wheel notch (WindowedView).
    // An Item, because the hover menu maps its position against it.
    Item {
        id: listMock

        property bool moving: false
        property bool wheelScrolling: false

        signal movementEnded()
    }

    // A list with no wheel glide of its own - a ListView, say.
    Item {
        id: plainListMock

        property bool moving: false

        signal movementEnded()
    }

    Component {
        id: messageViewComp

        MessageView {
            textAppearance: root.textAppearance
            previewAppearance: root.previewAppearance
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock

            joined: true
            messageContentType: Constants.messageContentType.messageType
            messageTimestamp: Date.now()
        }
    }

    Component {
        id: messagePairComp

        Column {
            spacing: 0
            width: 600

            MessageView {
                textAppearance: root.textAppearance
                previewAppearance: root.previewAppearance
                width: parent.width

                rootStore: rootStoreMock
                messageStore: messageStoreMock
                chatContentModule: chatContentModuleMock

                joined: true
                messageId: "msg-1"
                senderId: "0xsender"
                senderDisplayName: "Sender"
                unparsedText: "first message"
                messageTimestamp: Date.now()
                messageContentType: Constants.messageContentType.messageType
            }

            MessageView {
                textAppearance: root.textAppearance
                previewAppearance: root.previewAppearance
                width: parent.width

                rootStore: rootStoreMock
                messageStore: messageStoreMock
                chatContentModule: chatContentModuleMock

                joined: true
                messageId: "msg-2"
                senderId: "0xother"
                senderDisplayName: "Other"
                unparsedText: "second message"
                messageTimestamp: Date.now() + 1
                messageContentType: Constants.messageContentType.messageType
            }
        }
    }

    // Stands in for Popups: records each emoji picker request and answers it
    // with a stub picker, right away or when the test says so.
    QtObject {
        id: pickerRequests

        property var requests: []
        property bool answerImmediately: true

        function answer(request) {
            const picker = pickerStubComp.createObject(root, request.params)
            picker.open()
            request.cb(picker)
            return picker
        }

        readonly property Connections connections: Connections {
            target: Global

            function onOpenEmojiPopupRequested(params, cb) {
                const request = { params, cb }
                pickerRequests.requests.push(request)
                if (pickerRequests.answerImmediately)
                    pickerRequests.answer(request)
            }
        }
    }

    Component {
        id: pickerStubComp

        Popup {
            objectName: "pickerStub"

            property Item directParent
            property real relativeX
            property real relativeY

            signal emojiSelected(string emoji, bool atCursor, string hexcode)

            width: 370
            height: 440
            onClosed: destroy()
        }
    }

    Component {
        id: skinToneModelComp
        SkinToneFilteredEmojiModel {
            emojiModel: SQUtils.Emoji.emojiModel
        }
    }

    Component {
        id: signalSpyComp
        SignalSpy {}
    }

    Component { id: threadSpyComponent; SignalSpy { signalName: "openThread" } }
    QtObject {
        id: threadMessageModule
        readonly property int chatType: Constants.chatType.oneToOne
        function getChatId() { return "chat-1" }
    }

    TestCase {
        name: "MessageViewHoverContextMenu"
        when: windowShown

        function init() {
            pickerRequests.requests = []
            pickerRequests.answerImmediately = true
            listMock.moving = false
            listMock.wheelScrolling = false
            plainListMock.moving = false
        }

        function messageInList(list, id) {
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: id,
                senderId: "0xsender",
                senderDisplayName: "Sender",
                unparsedText: "a message in a list",
                chatLogView: list
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")
            return view
        }

        function messageViewReady(view) {
            return view.status === Loader.Ready
        }

        function findMessageDelegate(view) {
            const bubble = findChild(view, "StatusMessage_textMessage")
            if (!bubble)
                return null

            let item = bubble
            while (item && item.effectiveHovered === undefined)
                item = item.parent
            return item
        }

        function hasQuickActionsMenu(view) {
            const menu = findChild(view, "MessageContextMenuView")
            return !!menu && menu.opened
        }

        function hoverMessageDelegate(view) {
            const delegate = findMessageDelegate(view)
            verify(!!delegate, "message delegate must exist")
            mouseMove(delegate, Math.max(1, delegate.width / 2), Math.max(1, delegate.height / 2))
            return delegate
        }

        function test_threadActionRoutesParentAndExistingThread_data() {
            return [
                {tag: "create-hover", expanded: false, hasThread: false},
                {tag: "open-hover", expanded: false, hasThread: true},
                {tag: "create-menu", expanded: true, hasThread: false},
                {tag: "open-menu", expanded: true, hasThread: true}
            ]
        }

        function test_threadActionRoutesParentAndExistingThread(data) {
            messageStoreMock.messageModule = threadMessageModule
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: "parent", unparsedText: "Parent message", threadsFeatureEnabled: true,
                hasThread: data.hasThread, threadId: "existing-thread", threadTitle: "Existing title"
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000)
            const spy = createTemporaryObject(threadSpyComponent, root, {target: view})
            view.openMessageContextMenu(null, Qt.point(0, 0), "", {openExpanded: data.expanded})
            const menu = findChild(view, "MessageContextMenuView")
            verify(!!menu)
            if (data.expanded) {
                let triggered = false
                for (let i = 0; i < menu.count; ++i) {
                    const action = menu.actionAt(i)
                    if (action?.objectName === "messageContextMenu_openThread") {
                        verify(action.enabled)
                        action.trigger()
                        triggered = true
                        break
                    }
                }
                verify(triggered)
            } else {
                const row = findChild(menu, "messageContextMenu_singleRowActions")
                const thread = findChild(row, "messageContextMenu_openThread")
                verify(thread.visible)
                mouseClick(thread)
            }
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], data.hasThread ? "existing-thread" : "")
            compare(spy.signalArguments[0][2], "parent")
            messageStoreMock.messageModule = null
        }

        function test_mouseHoverOpensQuickActionsMenu() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: "msg-hover",
                senderId: "0xsender",
                senderDisplayName: "Sender",
                unparsedText: "hover me"
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")

            hoverMessageDelegate(view)
            tryVerify(() => hasQuickActionsMenu(view), 3000,
                      "mouse hover must open the quick-actions context menu")
        }

        function test_hoverDoesNotOpenQuickActionsWhenInPinnedPopup() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: "msg-pinned-popup",
                senderId: "0xsender",
                senderDisplayName: "Sender",
                unparsedText: "pinned popup message",
                isInPinnedPopup: true,
                joined: true
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")

            const delegate = hoverMessageDelegate(view)
            verify(delegate.disableHover)
            delegate.hoverChanged(view.messageId, true)
            verify(!hasQuickActionsMenu(view),
                   "hover must not open the chat quick-actions menu inside a pinned popup")
        }

        // While the list moves under a still pointer, every message passing under
        // it would be "hovered" - highlighted, with its menu popping up. Once the
        // list settles, the same pointer gets both.
        function checkNoHoverWhileScrolling(setScrolling) {
            const view = messageInList(listMock, "msg-scrolling")

            setScrolling(true)
            const delegate = hoverMessageDelegate(view)
            waitForRendering(view)
            verify(!delegate.hovered, "no hover highlight while the list scrolls")
            verify(!hasQuickActionsMenu(view), "and no hover menu")

            setScrolling(false)
            mouseMove(delegate, delegate.width / 2 + 2, delegate.height / 2)
            tryVerify(() => delegate.hovered && hasQuickActionsMenu(view), 3000,
                      "both come back once the list settles")
        }

        function test_noHoverWhileTheListMoves() {
            checkNoHoverWhileScrolling(on => listMock.moving = on)
        }

        // A WindowedView wheel glide is no movement to Flickable: `moving` stays
        // false through it.
        function test_noHoverWhileTheListGlides() {
            checkNoHoverWhileScrolling(on => listMock.wheelScrolling = on)
        }

        // Left open, the menu would stay where it was opened while its message
        // moves on - until the hover-exit delay ran out.
        function test_aHoverMenuClosesAsScrollingStarts() {
            const view = messageInList(listMock, "msg-hover-menu")

            hoverMessageDelegate(view)
            tryVerify(() => hasQuickActionsMenu(view), 3000, "the hover menu opened")

            listMock.wheelScrolling = true
            verify(!hasQuickActionsMenu(view), "closed at once, not after the hover-exit delay")
        }

        function test_aMenuTheUserOpenedStaysWhileScrolling() {
            const view = messageInList(listMock, "msg-user-menu")
            const delegate = findMessageDelegate(view)
            verify(!!delegate)

            view.openMessageContextMenu(delegate, Qt.point(10, 10))
            tryVerify(() => hasQuickActionsMenu(view), 3000, "the menu opened")

            listMock.wheelScrolling = true
            for (let i = 0; i < 3; ++i)
                waitForRendering(view)
            verify(hasQuickActionsMenu(view), "a menu the user opened is theirs to close")
        }

        function test_noMenuOpensWhileScrolling() {
            const view = messageInList(listMock, "msg-no-menu")
            const delegate = findMessageDelegate(view)
            verify(!!delegate)

            listMock.wheelScrolling = true
            view.openMessageContextMenu(delegate, Qt.point(10, 10))
            verify(!hasQuickActionsMenu(view), "no menu while the list scrolls")

            // asked for explicitly, it opens at once - the delay is hover's
            listMock.wheelScrolling = false
            view.openMessageContextMenu(delegate, Qt.point(10, 10))
            verify(hasQuickActionsMenu(view), "and it opens as soon as the list settles")
        }

        // Hover comes back a little after the scroll ends, not with it.
        function test_hoverResumesOnlyOnceTheScrollHasSettled() {
            const view = messageInList(listMock, "msg-resume")
            const delegate = hoverMessageDelegate(view)

            listMock.wheelScrolling = true
            listMock.wheelScrolling = false
            verify(delegate.disableHover, "still off right after the scroll")

            tryVerify(() => !delegate.disableHover, 2000, "back on after the delay")
            mouseMove(delegate, delegate.width / 2 + 2, delegate.height / 2)
            tryVerify(() => hasQuickActionsMenu(view), 3000, "and the hover menu works again")
        }

        // Wheel notches are separate glides with gaps between them. Hover must not
        // come back in a gap, or the message under the pointer blinks.
        function test_hoverStaysOffBetweenQuickNotches() {
            const view = messageInList(listMock, "msg-notches")
            const delegate = hoverMessageDelegate(view)

            // Timed by the clock: waitForRendering() waits for a frame, and with
            // nothing changing on screen none comes until its timeout.
            const elapse = ms => {
                const start = Date.now()
                tryVerify(() => Date.now() - start >= ms, ms + 1000)
            }

            for (let notch = 0; notch < 5; ++notch) {
                listMock.wheelScrolling = true
                elapse(50)
                listMock.wheelScrolling = false

                // a gap a quick spin leaves between two glides
                elapse(100)
                verify(delegate.disableHover, "hover stayed off in gap " + notch)
                verify(!delegate.hovered && !hasQuickActionsMenu(view),
                       "no highlight and no menu in gap " + notch)
            }

            tryVerify(() => !delegate.disableHover, 2000, "back on once the notches stop")
        }

        // The glide is read only if the list has one.
        function test_aListWithoutAGlideOfItsOwn() {
            failOnWarning(/wheelScrolling|TypeError/)

            const view = messageInList(plainListMock, "msg-plain-list")

            hoverMessageDelegate(view)
            tryVerify(() => hasQuickActionsMenu(view), 3000, "hover works")

            plainListMock.moving = true
            verify(!hasQuickActionsMenu(view), "and a move closes the hover menu")
        }

        function test_hoverMenuClosesWhenPointerEntersMessageGap() {
            const pair = createTemporaryObject(messagePairComp, root)
            verify(!!pair)
            compare(pair.children.length, 2)

            const firstView = pair.children[0]
            const secondView = pair.children[1]
            tryVerify(() => messageViewReady(firstView) && messageViewReady(secondView),
                      5000, "both MessageView rows must be ready")

            const delegate = hoverMessageDelegate(firstView)
            tryVerify(() => hasQuickActionsMenu(firstView), 3000,
                      "hover must open the quick-actions menu before gap test")

            const gapPoint = delegate.mapToItem(pair, delegate.width / 2, delegate.height + 1)
            mouseMove(pair, gapPoint.x, gapPoint.y)

            tryVerify(() => !hasQuickActionsMenu(firstView), 2000,
                      "moving into the inter-message gap must close the hover menu")
            verify(!hasQuickActionsMenu(secondView),
                   "gap hover must not open a menu on the neighboring message")
        }

        function cleanup() {
            tryVerify(() => {
                findChild(root, "pickerStub")?.close()
                return !findChild(root, "pickerStub")
            })
        }

        function openedQuickActionsMenu(id, props = {}) {
            const view = createTemporaryObject(messageViewComp, root, Object.assign({
                messageId: id,
                senderId: "0xsender",
                senderDisplayName: "Sender",
                unparsedText: "react to me"
            }, props))
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")
            mouseMove(root, root.width - 1, root.height - 1)
            hoverMessageDelegate(view)
            tryVerify(() => hasQuickActionsMenu(view), 3000)
            return { view, menu: findChild(view, "MessageContextMenuView") }
        }

        function test_reactionBarUsesTheGivenModel() {
            const model = createTemporaryObject(skinToneModelComp, root)
            const { menu } = openedQuickActionsMenu("msg-bar", { reactionEmojiModel: model })
            compare(menu.emojiModel, model)
        }

        function test_reactionPickerIsRequestedNextToTheClick() {
            const { view, menu } = openedQuickActionsMenu("msg-react")
            menu.openEmojiPopup(view, { x: 400, y: 10 })

            compare(pickerRequests.requests.length, 1)
            const params = pickerRequests.requests[0].params
            compare(params.directParent, view)
            compare(params.closePolicy, Popup.CloseOnEscape | Popup.CloseOnPressOutside)

            const picker = findChild(root, "pickerStub")
            compare(picker.relativeX, 400 - picker.width)
            compare(picker.relativeY, 10 + Theme.bigPadding)
        }

        function test_reactionReachesTheMessage() {
            const { view, menu } = openedQuickActionsMenu("msg-toggle")
            const spy = signalSpyComp.createObject(root, { target: view, signalName: "emojiReactionToggled" })
            menu.openEmojiPopup(view, { x: 400, y: 10 })

            findChild(root, "pickerStub").emojiSelected("\u2764\uFE0F", true, "2764")

            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "msg-toggle")
            compare(spy.signalArguments[0][1], "2764")
        }

        // the press that closes the picker must not reopen it on release
        function test_noReopenRightAfterClosing() {
            const { view, menu } = openedQuickActionsMenu("msg-debounce")
            menu.openEmojiPopup(view, { x: 400, y: 10 })
            findChild(root, "pickerStub").close()

            menu.openEmojiPopup(view, { x: 400, y: 10 })
            compare(pickerRequests.requests.length, 1)

            wait(150)
            menu.openEmojiPopup(view, { x: 400, y: 10 })
            compare(pickerRequests.requests.length, 2)
        }

        // a pooled row can be retargeted while its picker is open
        function test_openPickerClosesWhenTheRowIsRetargeted() {
            const { view, menu } = openedQuickActionsMenu("msg-open-old")
            const spy = signalSpyComp.createObject(root, { target: view, signalName: "emojiReactionToggled" })
            menu.openEmojiPopup(view, { x: 400, y: 10 })
            const picker = findChild(root, "pickerStub")
            tryCompare(picker, "opened", true)

            view.messageId = "msg-open-new"
            picker.emojiSelected("\u2764\uFE0F", true, "2764")
            compare(spy.count, 0)
            tryCompare(picker, "visible", false)

            menu.openEmojiPopup(view, { x: 400, y: 10 })
            compare(pickerRequests.requests.length, 2)
        }

        // a pooled row can be retargeted before an asynchronous first open answers
        function test_pickerForARetargetedRowIsClosed() {
            pickerRequests.answerImmediately = false
            const { view, menu } = openedQuickActionsMenu("msg-old")
            const spy = signalSpyComp.createObject(root, { target: view, signalName: "emojiReactionToggled" })
            menu.openEmojiPopup(view, { x: 400, y: 10 })

            view.messageId = "msg-new"
            const picker = pickerRequests.answer(pickerRequests.requests[0])
            tryCompare(picker, "visible", false)
            picker.emojiSelected("\u2764\uFE0F", true, "2764")
            compare(spy.count, 0)
        }
    }
}
