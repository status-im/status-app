import QtQuick
import QtTest

import StatusQ.Components
import AppLayouts.Chat.popups
import "../../../ui/app/AppLayouts/Chat/stores" as RealStores
import utils

Item {
    id: root
    width: 800
    height: 600

    property var activePopup: null
    property var openedMenu: null
    property string openedChatId

    QtObject {
        id: localAccountSensitiveSettings
        property bool showDeleteThreadWarning: true
    }

    QtObject {
        id: mainModule
        readonly property bool isOnline: true
        readonly property var activeSection: ({ id: "section" })
    }

    Connections {
        target: Global
        function onOpenPopupRequested(component, params) {
            root.activePopup = component.createObject(root, params || {})
            root.activePopup.open()
        }
    }

    QtObject {
        id: messages
        property var model: null
        property bool allowed: true
        property bool threadDeletePending: false
        property bool threadEditPending: false
        property string deletedId
        property bool messageSearchOngoing: false
        property bool loading: false
        property bool amIChatAdmin: false
        property bool isPinMessageAllowedForMembers: false
        property int chatType: Constants.chatType.oneToOne
        property string chatColor: "#4360df"
        property string chatIcon: ""
        property bool keepUnread: false
        property string threadId: ""
        property string threadName: ""
        property string threadParentChatName: ""
        property bool canEditThread: false
        signal threadDeleteFinished(string error)
        function getChatId() { return "parent" }
        function getSectionId() { return "" }
        function canManageThreadById(id) { return allowed && id === "thread" }
        function deleteThreadById(id) { deletedId = id }
    }

    QtObject {
        id: otherMessages
        property var model: null
        property bool amIChatAdmin: false
        property bool isPinMessageAllowedForMembers: false
        property bool messageSearchOngoing: false
        property bool loading: false
        property int chatType: Constants.chatType.oneToOne
        property string chatColor: "#4360df"
        property string chatIcon: ""
        property bool keepUnread: false
        property string threadId: ""
        property string threadName: ""
        property string threadParentChatName: ""
        property bool canEditThread: false
        property bool threadEditPending: false
        property bool threadDeletePending: false
        signal threadDeleteFinished(string error)
        function getChatId() { return "other" }
        function getSectionId() { return "" }
        function deleteThreadById(id) {}
    }

    QtObject {
        id: content
        readonly property var messagesModule: messages
    }

    QtObject {
        id: section
        property string requestedChatId
        property string readChatId
        property string readThreadId
        function getItemAsJson(id) {
            return JSON.stringify({
                itemId: id, isThread: true, parentChatId: "parent", name: "Thread"
            })
        }
        function prepareChatContentModuleForChatId(id) { requestedChatId = id }
        function getChatContentModule() { return content }
        function markAllMessagesRead(chatId, threadId) {
            readChatId = chatId
            readThreadId = threadId
        }
    }

    ListModel {
        id: chats
        ListElement {
            itemId: "parent"
            name: "Parent"
            isThread: false
            categoryId: ""
            type: 1
            muted: false
            active: true
            blocked: false
            hasUnreadMessages: false
            notificationsCount: 0
            highlight: false
            icon: ""
            emoji: ""
            color: ""
            colorId: 0
            categoryOpened: true
            hidden: false
            usesDefaultName: false
            onlineStatus: 0
            requiresPermissions: false
            locked: false
            isCategory: false
            position: 0
            categoryPosition: -1
            shouldBeHiddenBecausePermissionsAreNotMet: false
        }
        ListElement {
            itemId: "thread"
            name: "Thread"
            isThread: true
            categoryId: ""
            type: 1
            muted: false
            active: false
            blocked: false
            hasUnreadMessages: true
            notificationsCount: 1
            highlight: false
            icon: ""
            emoji: ""
            color: ""
            colorId: 0
            categoryOpened: true
            hidden: false
            usesDefaultName: false
            onlineStatus: 0
            requiresPermissions: false
            locked: false
            isCategory: false
            position: 1
            categoryPosition: -1
            shouldBeHiddenBecausePermissionsAreNotMet: false
        }
    }

    Component {
        id: messageStoreComponent
        RealStores.MessageStore {
            messageModule: messages
        }
    }
    Component {
        id: threadMenuComponent
        ThreadListContextMenu {
            sectionModule: section
            onOpened: root.openedMenu = this
        }
    }
    Component {
        id: chatMenuComponent
        QtObject {
            property var openHandler: id => { root.openedChatId = id }
            property var closeHandler
            function popup(x, y) { openHandler() }
        }
    }
    Component {
        id: contactsComponent
        StatusChatList {
            width: 300
            height: 600
            model: chats
            popupMenu: chatMenuComponent
            threadPopupMenu: threadMenuComponent
        }
    }
    Component {
        id: communityComponent
        StatusChatListAndCategories {
            width: 300
            height: 600
            model: chats
            chatListPopupMenu: chatMenuComponent
            threadPopupMenu: threadMenuComponent
        }
    }

    TestCase {
        name: "ThreadListContextMenu"
        when: windowShown

        SignalSpy {
            id: renameSpy
            signalName: "renameThreadRequested"
        }
        SignalSpy {
            id: toastSpy
            target: Global
            signalName: "displayToastMessage"
        }

        function init() {
            messages.allowed = true
            messages.threadDeletePending = false
            messages.threadEditPending = false
            messages.deletedId = ""
            section.readChatId = ""
            section.readThreadId = ""
            root.openedMenu = null
            root.openedChatId = ""
            localAccountSensitiveSettings.showDeleteThreadWarning = true
        }

        function cleanup() {
            if (root.activePopup) {
                root.activePopup.close()
                root.activePopup.destroy()
                root.activePopup = null
            }
            if (root.openedMenu)
                root.openedMenu.close()
        }

        function openThreadMenu(component) {
            const list = createTemporaryObject(component, root)
            verify(!!list, "Component exists")
            let row
            tryVerify(() => { row = findChild(list, "Thread"); return !!row })
            mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton)
            tryVerify(() => !!root.openedMenu && root.openedMenu.opened)
            tryCompare(root.openedMenu, "threadId", "thread")
            tryCompare(section, "requestedChatId", "parent")
            tryCompare(root, "openedChatId", "")
            return root.openedMenu
        }

        function action(menu, objectName) {
            const entry = findChild(menu, objectName)
            verify(!!entry, "Object exists")
            return entry
        }

        function test_rightClickActions_data() {
            return [
                { tag: "contacts", component: contactsComponent },
                { tag: "community", component: communityComponent }
            ]
        }

        function test_rightClickActions(data) {
            const menu = openThreadMenu(data.component)
            const expected = [
                "threadContextMenu_editName", "threadContextMenu_follow",
                "threadContextMenu_muteThread", "threadContextMenu_markAsRead",
                "threadContextMenu_delete"
            ]
            for (const name of expected)
                tryCompare(action(menu, name), "enabled", true)
            tryCompare(action(menu, "threadContextMenu_copyShare"), "enabled", false)
            tryCompare(action(menu, "threadContextMenu_pin"), "enabled", false)
            tryCompare(menu, "editEnabled", true)
            tryCompare(menu, "deleteEnabled", true)
            tryVerify(() => {
                const labels = []
                for (let i = 0; i < menu.count; ++i) {
                    const item = menu.itemAt(i)
                    if (item.visible && item.text !== undefined)
                        labels.push(item.text)
                }
                return JSON.stringify(labels) === JSON.stringify([
                    qsTr("Edit name"), qsTr("Follow"), qsTr("Mute thread"),
                    qsTr("Mark as read"), qsTr("Delete")
                ])
            })
        }

        function test_markAsReadTargetsClickedThread() {
            const menu = openThreadMenu(contactsComponent)
            action(menu, "threadContextMenu_markAsRead").trigger()
            tryCompare(section, "readChatId", "parent")
            tryCompare(section, "readThreadId", "thread")
        }

        function test_renameTargetsClickedThread() {
            const menu = openThreadMenu(contactsComponent)
            renameSpy.target = menu
            renameSpy.clear()
            action(menu, "threadContextMenu_editName").trigger()
            tryCompare(renameSpy, "count", 1)
            compare(renameSpy.signalArguments[0][0], "thread")
            compare(renameSpy.signalArguments[0][1], "Thread")
            compare(renameSpy.signalArguments[0][2], "parent")
        }

        function test_deleteConfirmsClickedThread() {
            const menu = openThreadMenu(communityComponent)
            action(menu, "threadContextMenu_delete").trigger()
            tryVerify(() => !!root.activePopup && root.activePopup.opened)
            compare(messages.deletedId, "")
            menu.close()
            root.activePopup.confirmButtonClicked()
            tryCompare(messages, "deletedId", "thread")
        }

        function test_deleteErrorIsReportedOnlyByRequestingStore() {
            const requestingStore = createTemporaryObject(messageStoreComponent, root)
            verify(!!requestingStore, "Component exists")
            const observingStore = createTemporaryObject(messageStoreComponent, root)
            verify(!!observingStore, "Component exists")
            toastSpy.clear()
            requestingStore.deleteThreadById("thread")
            messages.threadDeleteFinished("Deletion failed")
            tryCompare(toastSpy, "count", 1)
            compare(toastSpy.signalArguments[0][1], "Deletion failed")
            compare(requestingStore.threadDeleteRequestedById, false)
            compare(observingStore.threadDeleteRequestedById, false)
        }

        function test_permissionErrorHasTranslatedMessage() {
            const store = createTemporaryObject(messageStoreComponent, root)
            verify(!!store, "Component exists")
            compare(store.threadDeleteErrorMessage("thread-delete-permission-denied"),
                    qsTr("Only the thread creator or an admin can delete this thread"))
        }

        function test_deleteErrorRemainsAttachedToOriginalModule() {
            const requestingStore = createTemporaryObject(messageStoreComponent, root)
            verify(!!requestingStore, "Component exists")
            toastSpy.clear()
            requestingStore.deleteThreadById("thread")
            requestingStore.messageModule = otherMessages
            compare(requestingStore.threadDeletePending, true)
            messages.threadDeleteFinished("Deletion failed")
            tryCompare(toastSpy, "count", 1)
            compare(toastSpy.signalArguments[0][1], "Deletion failed")
            compare(requestingStore.threadDeleteRequestedById, false)
            compare(requestingStore.threadDeletePending, false)
        }

        function test_permissionsAndPendingRequests() {
            messages.allowed = false
            const menu = openThreadMenu(contactsComponent)
            tryCompare(menu, "deleteEnabled", false)
            tryCompare(menu, "editEnabled", false)
            menu.canManage = true
            tryCompare(menu, "deleteEnabled", true)
            messages.threadEditPending = true
            tryCompare(menu, "deleteEnabled", false)
            messages.threadEditPending = false
            messages.threadDeletePending = true
            tryCompare(menu, "editEnabled", false)
        }

        function test_normalChatsKeepTheirMenu() {
            const list = createTemporaryObject(contactsComponent, root)
            verify(!!list, "Component exists")
            let row
            tryVerify(() => { row = findChild(list, "Parent"); return !!row })
            mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton)
            tryCompare(root, "openedChatId", "parent")
            tryCompare(root, "openedMenu", null)
        }

        function test_threadMenuFallsBackToChatMenu() {
            const list = createTemporaryObject(contactsComponent, root, { threadPopupMenu: null })
            verify(!!list, "Component exists")
            let row
            tryVerify(() => { row = findChild(list, "Thread"); return !!row })
            mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton)
            tryCompare(root, "openedChatId", "thread")
            tryCompare(root, "openedMenu", null)
        }
    }
}
