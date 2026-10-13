import QtQuick
import QtTest

import utils

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 ChatHeaderContentView "more options" menu
 =========================================
 The header's ChatContextMenuView (objectName moreOptionsContextMenu) was an
 eager inline child — a full menu tree built at section load for every open
 chat, needed only after the More button is clicked.

 Flows:
 - no interaction        → menu not instantiated (perf intent, test 1)
 - More button clicked   → menu instantiated, configured via openHandler
   from the chat content module, and shown (test 2)
*/
Item {
    id: root

    width: 700
    height: 100

    QtObject {
        id: chatContentModuleMock

        property bool communityChat: false
        property bool chatAdmin: false

        readonly property var messagesModule: QtObject {
            property string threadId
            property string threadName: "Original thread"
            property string threadParentChatName: "general"
            property bool canEditThread: true
            property bool threadEditPending: false
            property string requestedName
            readonly property var model: null
            readonly property bool loading: false
            readonly property bool messageSearchOngoing: false
            readonly property bool amIChatAdmin: false
            readonly property bool isPinMessageAllowedForMembers: false
            readonly property string chatColor: ""
            readonly property string chatIcon: ""
            readonly property int chatType: Constants.chatType.communityChat
            readonly property bool keepUnread: false
            signal threadEditFinished(string error)
            function getChatId() { return "parent-chat" }
            function editThread(name) {
                requestedName = name
                threadEditPending = true
            }
        }

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property string name: "Contact 1"
            readonly property string description: ""
            readonly property string emoji: ""
            readonly property string color: "#4360DF"
            readonly property string icon: ""
            readonly property int type: chatContentModuleMock.communityChat
                                         ? Constants.chatType.communityChat
                                         : Constants.chatType.oneToOne
            readonly property bool muted: false
            readonly property int position: 0
            readonly property bool hideIfPermissionsNotMet: false
            readonly property bool belongsToCommunity: chatContentModuleMock.communityChat
            readonly property bool isUsersListAvailable: true
            readonly property bool canView: true
            readonly property bool canPost: true
        }

        function amIChatAdmin() { return chatContentModuleMock.chatAdmin }
    }

    ChatStores.RootStore {
        id: rootStoreMock

        function currentChatContentModule() { return chatContentModuleMock }
    }

    ChatHeaderContentView {
        id: header
        width: parent.width
        rootStore: rootStoreMock
    }

    TestCase {
        name: "ChatHeaderMenu"
        when: windowShown

        // INTENT (perf): the More menu must not be instantiated at load
        function test_01_menuNotBuiltAtLoad() {
            wait(200)
            verify(!findChild(header, "moreOptionsContextMenu"),
                   "the More menu must not exist before the button is clicked")
        }

        // clicking More instantiates and opens the configured menu
        function test_02_moreButtonOpensMenu() {
            const button = findChild(header, "chatToolbarMoreOptionsButton")
            verify(!!button)
            mouseClick(button)

            tryVerify(() => {
                const menu = findChild(header, "moreOptionsContextMenu")
                return !!menu && menu.opened
            }, 3000, "More must open the context menu")

            const menu = findChild(header, "moreOptionsContextMenu")
            compare(menu.chatId, "chat-1")
            menu.close()
            tryVerify(() => !menu.opened)
        }

        function openMoreMenu() {
            const button = findChild(header, "chatToolbarMoreOptionsButton")
            verify(!!button)
            mouseClick(button)
            tryVerify(() => {
                const menu = findChild(header, "moreOptionsContextMenu")
                return !!menu && menu.opened
            }, 3000, "More must open the context menu")
            return findChild(header, "moreOptionsContextMenu")
        }

        // The toolbar copies belongsToCommunity and amIChatAdmin into the
        // shared channel menu when More is opened.
        function test_03_communityChannelAdminActionsFollowTheHeader() {
            chatContentModuleMock.communityChat = true
            chatContentModuleMock.chatAdmin = false

            let menu = openMoreMenu()
            compare(menu.isCommunityChat, true)
            compare(menu.amIChatAdmin, false)
            compare(findChild(menu, "editChannelMenuItem").enabled, false)
            compare(findChild(menu, "deleteOrLeaveMenuItem").enabled, false)
            menu.close()
            tryVerify(() => !menu.opened)

            chatContentModuleMock.chatAdmin = true
            menu = openMoreMenu()
            compare(menu.amIChatAdmin, true)
            compare(findChild(menu, "editChannelMenuItem").enabled, true)
            compare(findChild(menu, "deleteOrLeaveMenuItem").enabled, true)
            menu.close()
            tryVerify(() => !menu.opened)

            chatContentModuleMock.communityChat = false
            chatContentModuleMock.chatAdmin = false
        }

        function test_04_selectedThreadHeaderWiresMenuAndRename() {
            const messages = chatContentModuleMock.messagesModule
            messages.threadId = "thread"
            compare(header.chatContentModule.messagesModule.threadId, "thread")
            compare(findChild(header, "chatHeaderMessageStore").threadId, "thread")
            tryVerify(() => !!findChild(header, "threadHeaderMenuButton"))
            const button = findChild(header, "threadHeaderMenuButton")
            verify(!!button)
            compare(findChild(header, "chatToolbarMoreOptionsButton").visible, false)
            mouseClick(button)
            const menu = findChild(header, "threadHeaderContextMenu")
            tryCompare(menu, "opened", true)
            menu.actionAt(0).trigger()
            tryVerify(() => !!findChild(header, "threadNameInput"))
            const input = findChild(header, "threadNameInput")
            input.text = "Renamed thread"
            input.accepted()
            compare(messages.requestedName, "Renamed thread")
            compare(messages.threadEditPending, true)
            messages.threadName = "Renamed thread"
            messages.threadEditPending = false
            messages.threadEditFinished("")
            tryVerify(() => !findChild(header, "threadNameInput"))
            messages.canEditThread = false
            compare(button.visible, false)
            messages.threadId = ""
            messages.canEditThread = true
        }
    }
}
