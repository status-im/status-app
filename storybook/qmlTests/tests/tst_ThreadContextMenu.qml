import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ
import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Chat.popups
import shared.controls.chat.menuItems
import utils

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: menuComponent

        ThreadContextMenu {
            closePolicy: Popup.NoAutoClose
            visible: true
            threadLinkToCopyShare: "https://acme.org/link-to-this-thread"
            isMobile: false
            followed: false
            muted: false
            pinned: false
            pinEnabled: true
            deleteEnabled: true

            // Test-only override so each test can drive the "do not show
            // again" persisted setting without touching the real Settings
            // singleton (localAccountSensitiveSettings is dependency-injected
            // via QML scope lookup; in the app it is a real Settings object).
            property alias showDeleteThreadWarning: localAccountSensitiveSettings.showDeleteThreadWarning

            QtObject {
                id: localAccountSensitiveSettings
                property bool showDeleteThreadWarning: true
            }
        }
    }

    Component {
        id: muteMenuComponent
        MuteChatMenuItem {}
    }

    // The delete confirmation is opened via Global.openPopup(), not as a
    // child of the menu (see ChatContextMenuView.qml for the same pattern),
    // so tests must intercept it the same way the real popup host would.
    property var activePopup: null

    Connections {
        target: Global
        function onOpenPopupRequested(popupComponent, params) {
            if (root.activePopup)
                root.activePopup.destroy()
            root.activePopup = popupComponent.createObject(root, params || {})
            if (root.activePopup)
                root.activePopup.open()
        }
    }

    // Actions/items are looked up by objectName (set on each entry in
    // ThreadContextMenu.qml) rather than by display text or type, so
    // renaming/relabeling/localizing an entry can't silently break the test.
    // StatusAction-backed entries surface via actionAt(); Item-backed entries
    // (e.g. StatusSuccessAction) surface via itemAt().
    function findEntry(menu, objectName) {
        for (let i = 0; i < menu.count; ++i) {
            const action = menu.actionAt(i)
            if (action && action.objectName === objectName)
                return action

            const item = menu.itemAt(i)
            if (item && item.objectName === objectName)
                return item
        }
        return null
    }

    TestCase {
        name: "ThreadContextMenu"
        when: windowShown

        SignalSpy {
            id: editSpy
            signalName: "editNameRequested"
        }
        SignalSpy {
            id: followSpy
            signalName: "followRequested"
        }
        SignalSpy {
            id: unfollowSpy
            signalName: "unfollowRequested"
        }
        SignalSpy {
            id: muteSpy
            signalName: "muteRequested"
        }
        SignalSpy {
            id: unmuteSpy
            signalName: "unmuteRequested"
        }
        SignalSpy {
            id: markAsReadSpy
            signalName: "markAsReadRequested"
        }
        SignalSpy {
            id: pinSpy
            signalName: "pinRequested"
        }
        SignalSpy {
            id: unpinSpy
            signalName: "unpinRequested"
        }
        SignalSpy {
            id: deleteSpy
            signalName: "deleteRequested"
        }

        function cleanup() {
            if (root.activePopup) {
                root.activePopup.close()
                root.activePopup.destroy()
                root.activePopup = null
            }
        }

        function createMenu(props) {
            const menu = createTemporaryObject(menuComponent, root, props || {})
            verify(!!menu)
            menu.open()
            tryCompare(menu, "opened", true)
            return menu
        }

        function createMuteMenu(props) {
            const menu = createTemporaryObject(muteMenuComponent, root, props || {})
            verify(!!menu)
            menu.open()
            tryCompare(menu, "opened", true)
            return menu
        }

        function test_01_actions_are_exposed_and_menu_labels_match_state() {
            const menu = createMenu({
                isMobile: true,
                followed: true,
                muted: true,
                pinned: true,
                pinEnabled: true,
                deleteEnabled: true
            })

            const editNameEntry = findEntry(menu, "threadContextMenu_editName")
            verify(!!editNameEntry)
            compare(editNameEntry.text, qsTr("Edit name"))

            const followEntry = findEntry(menu, "threadContextMenu_follow")
            verify(!!followEntry)
            compare(followEntry.text, qsTr("Unfollow"))

            const muteThreadEntry = findChild(menu, "threadContextMenu_muteThread")
            verify(!!muteThreadEntry, "embedded MuteChatMenuItem instance not found")
            compare(muteThreadEntry.enabled, false, "mute entry must be disabled while already muted")

            const unmuteEntry = findEntry(menu, "threadContextMenu_unmuteThread")
            verify(!!unmuteEntry)
            compare(unmuteEntry.text, qsTr("Unmute thread"))
            compare(unmuteEntry.enabled, true)

            const markAsReadEntry = findEntry(menu, "threadContextMenu_markAsRead")
            verify(!!markAsReadEntry)
            compare(markAsReadEntry.text, qsTr("Mark as read"))

            const copyShareEntry = findEntry(menu, "threadContextMenu_copyShare")
            verify(!!copyShareEntry)
            compare(copyShareEntry.text, qsTr("Share link"))

            const pinEntry = findEntry(menu, "threadContextMenu_pin")
            verify(!!pinEntry)
            compare(pinEntry.text, qsTr("Unpin from list"))
            compare(pinEntry.enabled, true)

            const deleteEntry = findEntry(menu, "threadContextMenu_delete")
            verify(!!deleteEntry)
            compare(deleteEntry.text, qsTr("Delete"))
            compare(deleteEntry.enabled, true)

            const muteMenu = createMuteMenu()
            compare(muteMenu.count >= 6, true, "MuteChatMenuItem must expose all muting intervals")
            muteMenu.close()

            menu.close()
        }

        function test_02_signals_emit_for_each_action() {
            const menu = createMenu({
                isMobile: false,
                followed: false,
                muted: false,
                pinned: false,
                pinEnabled: true,
                deleteEnabled: true,
                showDeleteThreadWarning: false
            })

            editSpy.target = menu
            followSpy.target = menu
            unfollowSpy.target = menu
            muteSpy.target = menu
            unmuteSpy.target = menu
            markAsReadSpy.target = menu
            pinSpy.target = menu
            unpinSpy.target = menu
            deleteSpy.target = menu

            editSpy.clear(); followSpy.clear(); unfollowSpy.clear(); muteSpy.clear();
            unmuteSpy.clear(); markAsReadSpy.clear(); pinSpy.clear(); unpinSpy.clear(); deleteSpy.clear()

            // Trigger each real menu entry (rather than emitting the menu's
            // own signals directly) so a broken StatusAction.onTriggered
            // binding cannot pass this test.
            findEntry(menu, "threadContextMenu_editName").trigger()
            compare(editSpy.count, 1)

            findEntry(menu, "threadContextMenu_follow").trigger()
            compare(followSpy.count, 1)

            const muteThreadEntry = findChild(menu, "threadContextMenu_muteThread")
            verify(!!muteThreadEntry)
            muteThreadEntry.muteTriggered(Constants.MutingVariations.For15min)
            compare(muteSpy.count, 1)
            compare(muteSpy.signalArguments[0][0], Constants.MutingVariations.For15min)

            findEntry(menu, "threadContextMenu_markAsRead").trigger()
            compare(markAsReadSpy.count, 1)

            findEntry(menu, "threadContextMenu_pin").trigger()
            compare(pinSpy.count, 1)

            findEntry(menu, "threadContextMenu_delete").trigger()
            compare(deleteSpy.count, 1)

            menu.close()

            // Unfollow/unmute/unpin are only reachable (enabled) when the
            // thread is already followed/muted/pinned, so exercise them via
            // a second menu instance in that state.
            const reopenedMenu = createMenu({
                isMobile: false,
                followed: true,
                muted: true,
                pinned: true,
                pinEnabled: true,
                deleteEnabled: true
            })
            unfollowSpy.target = reopenedMenu
            unmuteSpy.target = reopenedMenu
            unpinSpy.target = reopenedMenu
            unfollowSpy.clear(); unmuteSpy.clear(); unpinSpy.clear()

            findEntry(reopenedMenu, "threadContextMenu_follow").trigger()
            compare(unfollowSpy.count, 1)

            findEntry(reopenedMenu, "threadContextMenu_unmuteThread").trigger()
            compare(unmuteSpy.count, 1)

            findEntry(reopenedMenu, "threadContextMenu_pin").trigger()
            compare(unpinSpy.count, 1)

            reopenedMenu.close()
        }

        function test_03_disabled_actions_stay_disabled() {
            const menu = createMenu({
                isMobile: false,
                followed: false,
                muted: false,
                pinned: false,
                pinEnabled: false,
                deleteEnabled: false
            })

            const pinEntry = findEntry(menu, "threadContextMenu_pin")
            verify(!!pinEntry)
            verify(!pinEntry.enabled)

            const deleteEntry = findEntry(menu, "threadContextMenu_delete")
            verify(!!deleteEntry)
            verify(!deleteEntry.enabled)

            menu.close()
        }

        // TDD: discrete true/false coverage of the "do not show again"
        // persisted setting gating the delete confirmation dialog.
        function test_04_delete_confirmation_gated_by_showDeleteThreadWarning_data() {
            return [
                { tag: "warning enabled: confirmation dialog gates delete", showDeleteThreadWarning: true },
                { tag: "warning disabled: delete fires immediately", showDeleteThreadWarning: false }
            ]
        }

        function test_04_delete_confirmation_gated_by_showDeleteThreadWarning(data) {
            const menu = createMenu({
                deleteEnabled: true,
                showDeleteThreadWarning: data.showDeleteThreadWarning
            })

            deleteSpy.target = menu
            deleteSpy.clear()

            const deleteEntry = findEntry(menu, "threadContextMenu_delete")
            verify(!!deleteEntry)
            deleteEntry.trigger()

            if (data.showDeleteThreadWarning) {
                tryVerify(() => !!root.activePopup, 2000, "confirmation dialog was not opened via Global.openPopup")
                compare(root.activePopup.objectName, "threadContextMenu_confirmDeletePopup")
                tryCompare(root.activePopup, "opened", true)
                compare(deleteSpy.count, 0, "delete must wait for confirmation when the warning is enabled")

                root.activePopup.confirmButtonClicked()
                compare(deleteSpy.count, 1)
            } else {
                verify(!root.activePopup, "confirmation dialog must not open when the warning is disabled")
                compare(deleteSpy.count, 1, "delete must fire immediately when the warning is disabled")
            }

            menu.close()
        }

        // TDD: discrete true/false coverage of the copy/share action, which
        // swaps label, icon, and delivery mechanism based on isMobile —
        // desktop copies to the clipboard, mobile hands off to native share.
        function test_05_copy_or_share_action_matches_isMobile_data() {
            return [
                {
                    tag: "desktop: Copy link",
                    isMobile: false,
                    expectedLabel: qsTr("Copy link"),
                    expectedIcon: "copy"
                },
                {
                    tag: "mobile: Share link",
                    isMobile: true,
                    expectedLabel: qsTr("Share link"),
                    expectedIcon: SQUtils.Utils.isIOS ? "share-ios" : "share-android"
                }
            ]
        }

        function test_05_copy_or_share_action_matches_isMobile(data) {
            const menu = createMenu({
                isMobile: data.isMobile,
                threadLinkToCopyShare: "https://acme.org/link-to-this-thread"
            })

            const copyShareEntry = findEntry(menu, "threadContextMenu_copyShare")
            verify(!!copyShareEntry)
            compare(copyShareEntry.text, data.expectedLabel)
            compare(copyShareEntry.icon.name, data.expectedIcon)

            // Known, different clipboard value so a successful copy/share is unambiguous.
            ClipboardUtils.setText("sentinel-not-copied")

            copyShareEntry.triggered()

            // On desktop and mobile alike, ShareUtils.shareText() writes to
            // the system clipboard (native share sheet handling is
            // platform-specific and out of scope for this offscreen suite).
            tryCompare(ClipboardUtils, "text", menu.threadLinkToCopyShare)

            menu.close()
        }
    }
}
