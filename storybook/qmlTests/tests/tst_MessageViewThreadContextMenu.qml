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
            let deleteAction
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action?.objectName === "threadContextMenu_delete")
                    deleteAction = action
            }
            verify(!!deleteAction)
            deleteAction.trigger()
            tryVerify(() => !!root.activePopup && root.activePopup.opened)
            compare(moduleMock.deletedThreadId, "")
            // The menu closes while its confirmation remains open.
            menu.close()
            root.activePopup.confirmButtonClicked()
            compare(moduleMock.deletedThreadId, "thread")
        }
    }
}
