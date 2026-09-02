import QtQuick
import QtTest

import StatusQ.Popups

import shared.views.chat
import utils

// RED tests for the threads PR stack (status-im/status-app#21351 .. #22245).
//
// MessageContextMenuView gained an "Open/Create Thread" action. Every other
// action row in that menu is gated on `root.expanded`, because StatusMenu sets
// `hideDisabledItems: true` - i.e. in that menu `enabled` doubles as `visible`.
// The thread action omits the `root.expanded` term, so it leaks into the
// collapsed (reaction-bar) form of the menu.
Item {
    id: root
    width: 600
    height: 400

    ListModel {
        id: emojiModel
    }
    property var testEmojiModel: emojiModel

    Component {
        id: menuComponent

        MessageContextMenuView {
            emojiModel: root.testEmojiModel
            myPublicKey: "me"
            messageSenderId: "me"
            unparsedText: "full message"
            messageContentType: Constants.messageContentType.messageType
            chatType: Constants.chatType.communityChat
            canPin: true
        }
    }

    TestCase {
        name: "ThreadsMessageContextMenu"
        when: windowShown

        function createMenu(props) {
            return createTemporaryObject(menuComponent, root, props || {})
        }

        // StatusMenu { hideDisabledItems: true } => a disabled action is not
        // rendered, so "enabled" is the visibility of the row.
        function visibleActionTexts(menu) {
            const texts = []
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (!item || item instanceof StatusMenuSeparator)
                    continue
                if (item.enabled && item.text)
                    texts.push(item.text)
            }
            return texts
        }

        function threadAction(menu) {
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.objectName === "messageContextMenu_openThread")
                    return action
            }
            return null
        }

        // RED: the collapsed menu is meant to show only the reaction row plus
        // the compact single-row actions. Because openThreadAction is not gated
        // on `root.expanded`, "Create Thread" is the one full-width action row
        // that survives collapsing, so right-clicking a message renders a menu
        // with a stray "Create Thread" entry under the reactions.
        function test_collapsedMenuDoesNotExposeThreadAction() {
            const menu = createMenu({
                openExpanded: false,
                threadsFeatureEnabled: true
            })
            menu.open()

            compare(menu.expanded, false)

            const action = threadAction(menu)
            verify(!!action, "expected the thread action to exist")
            verify(!action.enabled,
                   "the thread action must be hidden while the menu is collapsed, "
                   + "like every other action row in this menu")
            verify(visibleActionTexts(menu).indexOf(qsTr("Create Thread")) < 0,
                   "collapsed menu leaked the thread action: "
                   + JSON.stringify(visibleActionTexts(menu)))

            menu.close()
        }

        // Guard: expanding the menu must still surface the action.
        function test_expandedMenuExposesThreadAction() {
            const menu = createMenu({
                openExpanded: true,
                threadsFeatureEnabled: true
            })
            menu.open()

            verify(visibleActionTexts(menu).indexOf(qsTr("Create Thread")) >= 0)

            menu.close()
        }

        // Guard: with the feature flag off nothing thread-related is offered.
        function test_threadActionHiddenWhenFeatureFlagOff() {
            const menu = createMenu({
                openExpanded: true,
                threadsFeatureEnabled: false
            })
            menu.open()

            const action = threadAction(menu)
            verify(!!action)
            verify(!action.enabled)

            menu.close()
        }

        // Guard: unsupported chat types (public chat) must not offer threads,
        // matching status-go's Chat.SupportsThreads().
        function test_threadActionHiddenForUnsupportedChatType() {
            const menu = createMenu({
                openExpanded: true,
                threadsFeatureEnabled: true,
                chatType: Constants.chatType.publicChat
            })
            menu.open()

            const action = threadAction(menu)
            verify(!!action)
            verify(!action.enabled)

            menu.close()
        }
    }
}
