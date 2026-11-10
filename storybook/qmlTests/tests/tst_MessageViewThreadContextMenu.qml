import QtQuick
import QtTest
import utils
import shared.views.chat
import AppLayouts.Chat.stores as ChatStores

Item {
    id: root
    width: 800
    height: 600

    QtObject {
        id: localAccountSensitiveSettings
        property bool showDeleteThreadWarning: true
    }
    property var activePopup: null
    Connections {
        target: Global
        function onOpenPopupRequested(component, params) {
            root.activePopup = component.createObject(root, params || {})
            root.activePopup.open()
        }
    }

    ListModel { id: contacts }
    ChatStores.RootStore {
        id: rootStoreMock
        property var contactsModel: contacts
    }
    QtObject {
        id: moduleMock
        property string deletedThreadId: ""
        property bool threadDeletePending: false
        signal threadDeleteFinished(string error)
        function getChatId() { return "chat" }
        function canManageThreadById(id) { return id === "thread" }
        function deleteThreadById(id) { deletedThreadId = id }
        property string followedThreadId: ""
        property var followedValue: undefined
        function setThreadFollowedById(id, followed) {
            followedThreadId = id
            followedValue = followed
        }
    }
    ChatStores.MessageStore {
        id: messageStoreMock
        messageModule: moduleMock
    }
    QtObject {
        id: contentMock
        readonly property var chatDetails: QtObject {
            readonly property string id: "chat"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
        }
    }
    Component {
        id: viewComponent
        MessageView {
            width: 600
            joined: true
            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: contentMock
            chatId: "chat"
            messageId: "parent"
            senderId: "sender"
            senderDisplayName: "Sender"
            unparsedText: "Parent message"
            messageTimestamp: Date.now()
            messageContentType: Constants.messageContentType.messageType
            threadsFeatureEnabled: true
            hasThread: true
            threadId: "thread"
            threadOriginalMessageId: "parent"
            threadTitle: "Thread"
            threadMessagesCount: 2
        }
    }
    TestCase {
        name: "MessageViewThreadContextMenu"
        when: windowShown
        function test_rightClickOpensThreadMenuAndDeletesTheSummaryThread() {
            moduleMock.deletedThreadId = ""
            const view = createTemporaryObject(viewComponent, root)
            verify(!!view)
            tryCompare(view, "status", Loader.Ready)
            let card
            tryVerify(() => { card = findChild(view, "messageThreadSummary"); return !!card && card.height > 0 })
            mouseClick(card, card.width / 2, card.height / 2, Qt.RightButton)
            let menu
            tryVerify(() => { menu = findChild(view, "threadSummaryContextMenu"); return !!menu && menu.opened })
            wait(600) // A delayed message-hover menu must not replace the thread menu.
            verify(menu.opened)
            compare(menu.threadId, "thread")
            compare(menu.deleteEnabled, true)
            let copyShareAction
            let deleteAction
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                const item = menu.itemAt(i)
                if (action?.objectName === "threadContextMenu_delete")
                    deleteAction = action
                if (item?.objectName === "threadContextMenu_copyShare")
                    copyShareAction = item
            }
            verify(!!copyShareAction)
            compare(copyShareAction.enabled, false)
            verify(!!deleteAction)
            deleteAction.trigger()
            tryVerify(() => !!root.activePopup && root.activePopup.opened)
            compare(moduleMock.deletedThreadId, "")
            // The menu closes while its confirmation remains open.
            menu.close()
            root.activePopup.confirmButtonClicked()
            compare(moduleMock.deletedThreadId, "thread")
        }

        function test_followToggle_data() {
            return [
                { tag: "follow", followed: false, label: qsTr("Follow") },
                { tag: "unfollow", followed: true, label: qsTr("Unfollow") }
            ]
        }

        function test_followToggle(data) {
            moduleMock.followedThreadId = ""
            moduleMock.followedValue = undefined
            const view = createTemporaryObject(viewComponent, root, { threadFollowed: data.followed })
            verify(!!view)
            tryCompare(view, "status", Loader.Ready)
            let card
            tryVerify(() => { card = findChild(view, "messageThreadSummary"); return !!card && card.height > 0 })
            mouseClick(card, card.width / 2, card.height / 2, Qt.RightButton)
            let menu
            tryVerify(() => { menu = findChild(view, "threadSummaryContextMenu"); return !!menu && menu.opened })
            compare(menu.followed, data.followed)
            let followAction
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action?.objectName === "threadContextMenu_follow")
                    followAction = action
            }
            verify(!!followAction)
            compare(followAction.text, data.label)
            followAction.trigger()
            compare(moduleMock.followedThreadId, "thread")
            compare(moduleMock.followedValue, !data.followed)
        }
    }
}
