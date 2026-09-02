import QtQuick
import QtTest

import StatusQ.Popups

import shared.views.chat
import utils

// RED tests for the threads PR stack (status-im/status-app#21351 .. #22245).
//
// ChatContextMenuView is reused verbatim for the new "thread" rows that the
// stack inserts into the chat list (CommunityColumnView / ContactsColumnView
// set `isThread` and `threadId` from the model row). Every channel-scoped
// action in that menu was given a `!root.isThread` guard except
// `editChannelMenuItem`, and the thread row's `chatId` is the *thread* id
// (== the parent message id), not a channel id.
//
// StatusMenu sets `hideDisabledItems: true`, so `enabled` is also the row's
// visibility here.
Item {
    id: root
    width: 600
    height: 400

    property var editChannelCalls: []
    property var markAsReadCalls: []

    Component {
        id: menuComponent

        ChatContextMenuView {
            onDisplayEditChannelPopup: (chatId) => root.editChannelCalls.push(chatId)
            onMarkAllMessagesRead: (chatId, threadId) => root.markAsReadCalls.push({
                chatId: chatId, threadId: threadId })
        }
    }

    TestCase {
        name: "ThreadsChatContextMenu"
        when: windowShown

        function init() {
            root.editChannelCalls = []
            root.markAsReadCalls = []
        }

        function createMenu(props) {
            return createTemporaryObject(menuComponent, root, props || {})
        }

        function actionByObjectName(menu, objectName) {
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.objectName === objectName)
                    return action
            }
            return null
        }

        // A community thread row, seen by a channel admin.
        function threadRowProps() {
            return {
                isThread: true,
                isCommunityChat: true,
                amIChatAdmin: true,
                // the chat list assigns the row's own id, which for a thread row
                // is the thread id (== parent message id)
                chatId: "0xparentmessageid",
                threadId: "0xparentmessageid",
                chatName: "🧵 a thread",
                chatType: Constants.chatType.communityChat
            }
        }

        // RED: "Edit Channel" is the one channel-scoped action that was not
        // given the `!isThread` guard its siblings got. Right-clicking a thread
        // row as a channel admin therefore offers "Edit Channel", and triggering
        // it opens the channel-edit popup keyed on a *message* id.
        function test_editChannelIsNotOfferedOnAThreadRow() {
            const menu = createMenu(threadRowProps())

            const editAction = actionByObjectName(menu, "editChannelMenuItem")
            verify(!!editAction, "expected the edit-channel action to exist")
            verify(!editAction.enabled,
                   "Edit Channel must be hidden on a thread row, like every other "
                   + "channel-scoped action in this menu")
        }

        // RED: the same action, triggered, proves what it would do - it hands the
        // thread id (a message id) to the channel-edit popup.
        function test_editChannelOnAThreadRowDoesNotLeakTheThreadId() {
            const menu = createMenu(threadRowProps())

            const editAction = actionByObjectName(menu, "editChannelMenuItem")
            verify(!!editAction)
            if (editAction.enabled)
                editAction.trigger()

            compare(root.editChannelCalls.length, 0,
                    "the channel-edit popup was opened with "
                    + JSON.stringify(root.editChannelCalls)
                    + ", which is a message id, not a channel id")
        }

        // Guard: the actions that DID get the guard stay hidden.
        function test_guardedActionsAreHiddenOnAThreadRow() {
            const menu = createMenu(threadRowProps())

            const guarded = ["copyChannelLinkStatusAction",
                             "editNameAndImageMenuItem",
                             "chatMarkAsReadMenuItem",
                             "clearHistoryGroupMenuItem"]
            for (const name of guarded) {
                const action = actionByObjectName(menu, name)
                verify(!!action, "missing action " + name)
                verify(!action.enabled, name + " must be hidden on a thread row")
            }
        }

        // Guard: on a normal community channel the admin can still edit it.
        function test_editChannelStillOfferedOnARealChannel() {
            const menu = createMenu({
                isThread: false,
                isCommunityChat: true,
                amIChatAdmin: true,
                chatId: "0xchannelid",
                chatType: Constants.chatType.communityChat
            })

            const editAction = actionByObjectName(menu, "editChannelMenuItem")
            verify(!!editAction)
            verify(editAction.enabled)
        }
    }
}
