import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.TestHelpers

import utils

import AppLayouts.Chat.popups
import AppLayouts.Chat.stores as ChatStores

Item {
    id: root

    width: 1024
    height: 768

    ListModel {
        id: contactsModel
    }

    ListModel {
        id: pinnedModel
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel
    }

    ChatStores.MessageStore {
        id: messageStoreMock

        property int unpinCount: 0
        property string lastUnpinnedId: ""

        function unpinMessage(messageId) {
            unpinCount += 1
            lastUnpinnedId = messageId
        }

        function getMessageByIndexAsJson(index) {
            return {}
        }
    }

    Component {
        id: componentUnderTest

        PinnedMessagesPopup {
            anchors.centerIn: parent
            modal: false
            closePolicy: Popup.NoAutoClose
            store: rootStoreMock
            messageStore: messageStoreMock
            pinnedMessagesModel: pinnedModel
            chatId: "chat-1"
            joined: true
            destroyOnClose: false
        }
    }

    SignalSpy {
        id: unpinRequestedSpy
        signalName: "unpinMessageRequested"
    }

    SignalSpy {
        id: pinRequestedSpy
        signalName: "pinMessageRequested"
    }

    SignalSpy {
        id: jumpSpy
        signalName: "jumpToMessageRequested"
    }

    function appendPinnedMessage(messageId, text) {
        const message = {
            senderId: "0xsender",
            senderDisplayName: "Sender",
            senderIsAdded: true,
            messageText: text,
            unparsedText: text,
            timestamp: Date.now(),
            contentType: Constants.messageContentType.messageType,
            pinned: true
        }
        message.id = messageId
        pinnedModel.append(message)
    }

    StatusTestCase {
        name: "PinnedMessagesPopup"

        property PinnedMessagesPopup controlUnderTest: null

        function init() {
            pinnedModel.clear()
            messageStoreMock.unpinCount = 0
            messageStoreMock.lastUnpinnedId = ""
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            unpinRequestedSpy.target = controlUnderTest
            pinRequestedSpy.target = controlUnderTest
            jumpSpy.target = controlUnderTest
            unpinRequestedSpy.clear()
            pinRequestedSpy.clear()
            jumpSpy.clear()
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close()
                controlUnderTest.destroy()
                controlUnderTest = null
            }
            pinnedModel.clear()
            unpinRequestedSpy.clear()
            pinRequestedSpy.clear()
            jumpSpy.clear()
        }

        function openDialog() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            waitForRendering(controlUnderTest.contentItem)
        }

        function waitForDelegate() {
            const listView = findChild(controlUnderTest.contentItem, "pinnedMessagesPopup_listView")
            verify(!!listView)
            tryCompare(listView, "count", 1)
            tryVerify(() => !!listView.itemAtIndex(0))
            const mouseArea = findChild(listView.itemAtIndex(0), "pinnedMessagesPopup_delegateMouseArea")
            verify(!!mouseArea)
            mouseMove(root, 2, 2)
            return mouseArea
        }

        function openContextMenu(mouseArea) {
            mouseMove(root, 2, 2)
            mouseRightClick(mouseArea)
            tryVerify(() => !!findChild(mouseArea, "pinnedMessagesPopup_messageContextMenu"))
            return findChild(mouseArea, "pinnedMessagesPopup_messageContextMenu")
        }

        function menuItem(menu, objectName) {
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (item && item.objectName === objectName)
                    return item
            }
            return null
        }

        function test_emptyState() {
            openDialog()

            compare(controlUnderTest.title, qsTr("Pinned messages"))
            const emptyState = findChild(controlUnderTest.contentItem, "pinnedMessagesPopup_emptyState")
            verify(!!emptyState)
            verify(emptyState.visible)
            compare(emptyState.text, qsTr("Pinned messages will appear here."))
        }

        function test_hoverShowsFloatingUnpinButton() {
            appendPinnedMessage("msg-1", "hello pinned")
            openDialog()
            const mouseArea = waitForDelegate()
            const delegate = mouseArea.parent
            const unpinButton = findChild(delegate, "pinnedMessagesPopup_unpinButton")
            verify(!!unpinButton)
            tryCompare(unpinButton, "visible", false)

            mouseMove(mouseArea, Math.max(1, mouseArea.width / 2), Math.max(1, mouseArea.height / 2))
            tryCompare(unpinButton, "visible", true)

            mouseMove(root, 2, 2)
            tryCompare(unpinButton, "visible", false)
        }

        function test_unpinFromContextMenu() {
            appendPinnedMessage("msg-1", "hello pinned")
            openDialog()
            const menu = openContextMenu(waitForDelegate())
            const unpinItem = menuItem(menu, "pinnedMessagesPopup_unpin")
            verify(!!unpinItem)
            mouseClick(unpinItem)

            tryCompare(messageStoreMock, "unpinCount", 1)
            compare(messageStoreMock.lastUnpinnedId, "msg-1")
        }

        function test_unpinFromHoverButton() {
            appendPinnedMessage("msg-1", "hello pinned")
            openDialog()
            const mouseArea = waitForDelegate()

            mouseMove(mouseArea, Math.max(1, mouseArea.width / 2), Math.max(1, mouseArea.height / 2))
            const unpinButton = findChild(mouseArea.parent, "pinnedMessagesPopup_unpinButton")
            verify(!!unpinButton)
            tryCompare(unpinButton, "visible", true)
            mouseClick(unpinButton)

            tryCompare(unpinRequestedSpy, "count", 1)
            compare(unpinRequestedSpy.signalArguments[0][0], "msg-1")
        }

        function test_leftClickJumpsToMessageAndCloses() {
            appendPinnedMessage("msg-1", "hello pinned")
            openDialog()

            mouseClick(waitForDelegate())
            tryCompare(jumpSpy, "count", 1)
            compare(jumpSpy.signalArguments[0][0], "msg-1")
            tryCompare(controlUnderTest, "opened", false)
        }

        function test_pinLimitMode() {
            appendPinnedMessage("msg-1", "already pinned")
            controlUnderTest.messageToPin = "msg-to-pin"
            openDialog()

            compare(controlUnderTest.title, qsTr("Pin limit reached"))
            compare(controlUnderTest.subtitle, qsTr("Unpin a previous message first"))

            const mouseArea = waitForDelegate()
            const delegate = mouseArea.parent
            const radio = findChild(delegate, "pinnedMessagesPopup_radio")
            verify(!!radio)
            verify(radio.visible)

            mouseMove(mouseArea, Math.max(1, mouseArea.width / 2), Math.max(1, mouseArea.height / 2))
            const unpinButton = findChild(delegate, "pinnedMessagesPopup_unpinButton")
            verify(!!unpinButton)
            compare(unpinButton.visible, false)

            const confirmButton = findChild(controlUnderTest, "pinnedMessagesPopup_confirmPinButton")
            verify(!!confirmButton)
            verify(confirmButton.visible)
            compare(confirmButton.enabled, false)

            mouseClick(mouseArea)
            tryCompare(radio, "checked", true)
            tryCompare(controlUnderTest, "messageToUnpin", "msg-1")
            tryCompare(confirmButton, "enabled", true)

            mouseClick(confirmButton)
            tryCompare(unpinRequestedSpy, "count", 1)
            compare(unpinRequestedSpy.signalArguments[0][0], "msg-1")
            tryCompare(pinRequestedSpy, "count", 1)
            compare(pinRequestedSpy.signalArguments[0][0], "msg-to-pin")
            tryCompare(controlUnderTest, "opened", false)
        }

        function test_pinActionUnavailableHidesUnpin() {
            appendPinnedMessage("msg-1", "hello pinned")
            controlUnderTest.isPinActionAvailable = false
            openDialog()
            const mouseArea = waitForDelegate()
            const delegate = mouseArea.parent

            mouseMove(mouseArea, Math.max(1, mouseArea.width / 2), Math.max(1, mouseArea.height / 2))
            const unpinButton = findChild(delegate, "pinnedMessagesPopup_unpinButton")
            verify(!!unpinButton)
            compare(unpinButton.visible, false)

            const menu = openContextMenu(mouseArea)
            const unpinItem = menuItem(menu, "pinnedMessagesPopup_unpin")
            verify(!unpinItem || !unpinItem.enabled)
            const jumpItem = menuItem(menu, "pinnedMessagesPopup_jumpTo")
            verify(!!jumpItem)
            compare(jumpItem.enabled, true)
        }
    }
}
