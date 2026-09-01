import QtQuick
import QtTest

import StatusQ.Popups

import shared.views.chat
import utils

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
            chatType: Constants.chatType.oneToOne
            canPin: true
        }
    }

    SignalSpy {
        id: copySpy
        signalName: "copyToClipboard"
    }

    SignalSpy {
        id: pinSpy
        signalName: "pinMessage"
    }

    SignalSpy {
        id: unpinSpy
        signalName: "unpinMessage"
    }

    SignalSpy {
        id: deleteSpy
        signalName: "deleteMessage"
    }

    TestCase {
        name: "MessageContextMenuView"
        when: windowShown

        function createMenu(props) {
            return createTemporaryObject(menuComponent, root, props || {})
        }

        function enabledActionTexts(menu) {
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

        function triggerAction(menu, objectName) {
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.objectName === objectName) {
                    action.trigger()
                    return true
                }
            }
            return false
        }

        function singleRowAction(menu, objectName) {
            const row = findChild(menu, "messageContextMenu_singleRowActions")
            verify(!!row)
            return findChild(row, objectName)
        }

        function verifyNoHorizontalOverflow(menu) {
            verify(menu.contentItem.contentWidth <= menu.contentItem.availableWidth)
        }

        function test_collapsedUsesSingleRow() {
            const oneRow = createMenu({ openExpanded: false })
            oneRow.open()
            compare(oneRow.expanded, false)
            compare(oneRow.maxImplicitWidth, 328)
            compare(Math.round(oneRow.width), 328)
            verifyNoHorizontalOverflow(oneRow)
            compare(findChild(oneRow, "messageContextMenu_reactionsRow").countLimit, 3)
            oneRow.close()

            const expanded = createMenu({ openExpanded: true })
            expanded.open()
            compare(expanded.expanded, true)
            compare(expanded.maxImplicitWidth, 234)
            compare(Math.round(expanded.width), 234)
            verifyNoHorizontalOverflow(expanded)
            const expandedReactionsRow = findChild(expanded, "messageContextMenu_reactionsRow")
            verify(!!expandedReactionsRow)
            verify(expandedReactionsRow.visible)
            verify(expandedReactionsRow.height > 0)
            const expandedSeparator = findChild(expanded, "messageContextMenu_reactionsSeparator")
            verify(!!expandedSeparator)
            verify(expandedSeparator.visible)
            expanded.close()
        }

        function test_moreExpandsReactionsToFitWidth() {
            const menu = createMenu({ openExpanded: false })
            menu.open()

            const reactionsRow = findChild(menu, "messageContextMenu_reactionsRow")
            verify(!!reactionsRow)
            compare(reactionsRow.countLimit, 3)

            const moreButton = singleRowAction(menu, "messageContextMenu_expand")
            verify(!!moreButton)
            mouseClick(moreButton)

            compare(menu.expanded, true)
            compare(reactionsRow.countLimit, 0)
            compare(menu.maxImplicitWidth, 328)
            compare(Math.round(menu.width), 328)
            verifyNoHorizontalOverflow(menu)

            menu.close()
        }

        function test_expandedActionsExposeExpectedLabels() {
            const menu = createMenu({ openExpanded: true })
            menu.open()

            const texts = enabledActionTexts(menu)
            verify(texts.indexOf(qsTr("Reply")) >= 0)
            verify(texts.indexOf(qsTr("Edit")) >= 0)
            verify(texts.indexOf(qsTr("Mark as unread")) >= 0)
            verify(texts.indexOf(qsTr("Copy message")) >= 0)
            verify(texts.indexOf(qsTr("Pin")) >= 0)
            verify(texts.indexOf(qsTr("Delete")) >= 0)
            verify(texts.indexOf(qsTr("Copy")) < 0)

            menu.close()
        }

        function test_expandedReactionsUseAvailableWidth() {
            const menu = createMenu({ openExpanded: true })
            menu.open()

            const reactionsRow = findChild(menu, "messageContextMenu_reactionsRow")
            verify(!!reactionsRow)
            compare(reactionsRow.countLimit, 0)

            menu.close()
        }

        function test_collapsedEditActionIsHiddenWhenUnavailable() {
            const menu = createMenu({
                openExpanded: false,
                messageSenderId: "someone-else"
            })
            menu.open()

            const editButton = singleRowAction(menu, "messageContextMenu_edit")
            verify(!!editButton)
            verify(!editButton.visible)
            const pinButton = singleRowAction(menu, "messageContextMenu_pin")
            verify(!!pinButton)
            verify(pinButton.visible)

            menu.close()
        }

        function test_singleRowPinMovesUpWhenEditIsUnavailable() {
            const menu = createMenu({
                openExpanded: false,
                messageSenderId: "someone-else"
            })
            menu.open()

            const editButton = singleRowAction(menu, "messageContextMenu_edit")
            verify(!!editButton)
            verify(!editButton.visible)
            const copyButton = singleRowAction(menu, "messageContextMenu_copy")
            verify(!!copyButton)
            verify(copyButton.visible)
            const pinButton = singleRowAction(menu, "messageContextMenu_pin")
            verify(!!pinButton)
            verify(pinButton.visible)
            compare(menu.maxImplicitWidth, 328)

            menu.close()
        }

        function test_singleRowPinStaysInOverflowWhenEditIsAvailable() {
            const menu = createMenu({ openExpanded: false })
            menu.open()

            const editButton = singleRowAction(menu, "messageContextMenu_edit")
            verify(!!editButton)
            verify(editButton.visible)
            const copyButton = singleRowAction(menu, "messageContextMenu_copy")
            verify(!!copyButton)
            verify(copyButton.visible)
            const pinButton = singleRowAction(menu, "messageContextMenu_pin")
            verify(!!pinButton)
            verify(!pinButton.visible)
            compare(menu.maxImplicitWidth, 328)

            menu.close()
        }

        function test_copyActionPrefersSelectedTextWhenPresent() {
            const menu = createMenu({ expanded: true, selectedText: "selected text" })
            copySpy.target = menu
            copySpy.clear()

            verify(triggerAction(menu, "messageContextMenu_copySelection"))
            compare(copySpy.count, 1)
            compare(copySpy.signalArguments[0][0], "selected text")

            copySpy.target = null
        }

        function test_copyMessageActionUsesUnparsedText() {
            const menu = createMenu({ expanded: true })
            copySpy.target = menu
            copySpy.clear()

            verify(triggerAction(menu, "messageContextMenu_copy"))
            compare(copySpy.count, 1)
            compare(copySpy.signalArguments[0][0], "full message")

            copySpy.target = null
        }

        function test_pinUnpinAndDeleteActionsEmitSignals() {
            const menu = createMenu({ expanded: true })
            pinSpy.target = menu
            deleteSpy.target = menu
            pinSpy.clear()
            deleteSpy.clear()

            verify(triggerAction(menu, "messageContextMenu_pin"))
            compare(pinSpy.count, 1)

            verify(triggerAction(menu, "messageContextMenu_delete"))
            compare(deleteSpy.count, 1)

            pinSpy.target = null
            deleteSpy.target = null

            const pinnedMenu = createMenu({ expanded: true, pinnedMessage: true })
            unpinSpy.target = pinnedMenu
            unpinSpy.clear()

            verify(triggerAction(pinnedMenu, "messageContextMenu_pin"))
            compare(unpinSpy.count, 1)

            unpinSpy.target = null
        }
    }
}
