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

        function test_collapsedModesUseExpectedWidthAndExpansionState() {
            const twoRows = createMenu({ openExpanded: false, collapsedSingleRow: false })
            twoRows.open()
            compare(twoRows.expanded, false)
            compare(twoRows.maxImplicitWidth, 234)
            twoRows.close()

            const oneRow = createMenu({ openExpanded: false, collapsedSingleRow: true })
            oneRow.open()
            compare(oneRow.expanded, false)
            compare(oneRow.maxImplicitWidth, 328)
            compare(findChild(oneRow, "messageContextMenu_landscapeReactionsRow").countLimit, 3)
            oneRow.close()

            const expanded = createMenu({ openExpanded: true, collapsedSingleRow: true })
            expanded.open()
            compare(expanded.expanded, true)
            compare(expanded.maxImplicitWidth, 234)
            expanded.close()
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

        function test_expandedLandscapeReactionsUseAvailableWidth() {
            const menu = createMenu({ openExpanded: true, collapsedSingleRow: true })
            menu.open()

            const reactionsRow = findChild(menu, "messageContextMenu_reactionsRow")
            verify(!!reactionsRow)
            compare(reactionsRow.countLimit, 0)

            menu.close()

            const regularMenu = createMenu({ openExpanded: true, collapsedSingleRow: false })
            regularMenu.open()

            const regularReactionsRow = findChild(regularMenu, "messageContextMenu_reactionsRow")
            verify(!!regularReactionsRow)
            compare(regularReactionsRow.countLimit, 4)

            regularMenu.close()
        }

        function test_collapsedEditActionIsDisabledWhenUnavailable() {
            const menu = createMenu({
                openExpanded: false,
                collapsedSingleRow: false,
                messageSenderId: "someone-else"
            })
            menu.open()

            const editButton = findChild(menu, "messageContextMenu_edit")
            verify(!!editButton)
            verify(!editButton.enabled)

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
