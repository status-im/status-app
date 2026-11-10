import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Chat.controls
import Storybook.Testing

Item {
    id: root
    width: 700
    height: 300

    Button {
        id: outside
        y: 200
        text: "Outside"
    }

    Component {
        id: headerComponent
        ThreadHeader {
            width: 500
            threadId: "thread-id"
            threadName: "Original"
            parentChatName: "# general"
            canEdit: true
            pending: false
        }
    }

    TestCase {
        name: "ThreadHeader"
        when: windowShown
        property ThreadHeader header

        SignalSpy {
            id: renameSpy
            signalName: "renameRequested"
        }
        SignalSpy {
            id: readSpy
            signalName: "markAsReadRequested"
        }
        SignalSpy {
            id: editSpy
            signalName: "editNameRequested"
        }
        SignalSpy {
            id: deleteSpy
            signalName: "deleteRequested"
        }
        InputMethodTester { id: ime }

        function init() {
            header = createTemporaryObject(headerComponent, root)
            verify(!!header)
            renameSpy.target = header
            renameSpy.clear()
            readSpy.target = header
            readSpy.clear()
            editSpy.target = header
            editSpy.clear()
            deleteSpy.target = header
            deleteSpy.clear()
        }

        function edit(text) {
            header.beginEditing()
            const input = findChild(header, "threadNameInput")
            verify(!!input)
            tryCompare(input, "activeFocus", true)
            input.selectAll()
            ime.commit(input, text)
            return input
        }

        function test_deletionPendingBlocksRenameAndReportsFailure() {
            header.deletePending = true
            header.beginEditing()
            compare(header.editing, false)
            compare(findChild(header, "threadHeaderMenuButton").enabled, false)
            header.deletePending = false
            header.deleteFinished("permission denied")
            const error = findChild(header, "threadNameError")
            verify(error.visible)
            verify(error.text.includes("permission denied"))
        }

        function test_enterSubmitsAndSuccessClosesEditor() {
            const input = edit("Updated")
            keyClick(Qt.Key_Return)
            compare(renameSpy.count, 1)
            compare(renameSpy.signalArguments[0][0], "Updated")
            compare(header.editing, true)
            header.pending = true
            keyClick(Qt.Key_Return)
            compare(renameSpy.count, 1)
            header.threadName = "Updated"
            header.pending = false
            header.editFinished("")
            compare(header.editing, false)
        }

        function test_escapeCancelsWithoutSending() {
            edit("Draft")
            keyClick(Qt.Key_Escape)
            compare(header.editing, false)
            compare(renameSpy.count, 0)
            compare(header.threadName, "Original")
        }

        function test_escapeDuringRequestCancelsOnlyTheEditor() {
            edit("Draft")
            keyClick(Qt.Key_Return)
            header.pending = true
            keyClick(Qt.Key_Escape)
            compare(header.editing, false)
            compare(renameSpy.count, 1)
            header.threadName = "Draft"
            header.pending = false
            header.editFinished("")
            compare(header.editing, false)
            compare(header.threadName, "Draft")
        }

        function test_inputFitsNarrowHeaderAndShowsPendingState() {
            header.width = 240
            const input = edit("A long draft that should scroll inside the input")
            tryVerify(() => input.width <= header.width)
            keyClick(Qt.Key_Return)
            header.pending = true
            verify(input.readOnly)
            verify(findChild(header, "threadNameError").visible)
            compare(findChild(header, "threadHeaderMenuButton").enabled, false)
        }

        function test_clickingAwayKeepsDraftAndDoesNotSend() {
            const input = edit("Draft")
            mouseClick(outside)
            compare(header.editing, true)
            compare(input.text, "Draft")
            compare(renameSpy.count, 0)
            input.forceActiveFocus()
            keyClick(Qt.Key_Return)
            compare(renameSpy.signalArguments[0][0], "Draft")
        }

        function test_failureKeepsDraftAndAllowsRetry() {
            const input = edit("Draft")
            keyClick(Qt.Key_Return)
            header.editFinished("edit-thread: invalid name")
            compare(header.editing, true)
            compare(input.text, "Draft")
            const error = findChild(header, "threadNameError")
            verify(error.visible)
            verify(error.text.indexOf("invalid name") >= 0)
            keyClick(Qt.Key_Return)
            compare(renameSpy.count, 2)
            header.editFinished("")
            compare(header.editing, false)
        }

        function test_deleteCancelsSubmittedRenameEditor() {
            edit("Draft")
            keyClick(Qt.Key_Return)
            compare(renameSpy.count, 1)

            mouseClick(findChild(header, "threadHeaderMenuButton"))
            const menu = findChild(header, "threadHeaderContextMenu")
            verify(!!menu)
            menu.deleteRequested()

            compare(deleteSpy.count, 1)
            compare(header.editing, false)
            header.editFinished("rename rejected during deletion")
            header.beginEditing()
            const retryInput = findChild(header, "threadNameInput")
            verify(!!retryInput)
            retryInput.text = "Retry"
            keyClick(Qt.Key_Return)
            compare(renameSpy.count, 2)
            compare(renameSpy.signalArguments[1][0], "Retry")
        }

        function test_remoteRenameDoesNotOverwriteDraftOrCompleteRequest() {
            const input = edit("Draft")
            keyClick(Qt.Key_Return)
            header.pending = true
            header.threadName = "Remote name"
            compare(header.editing, true)
            compare(input.text, "Draft")
            header.pending = false
            header.editFinished("Request failed")
            compare(input.text, "Draft")
            keyClick(Qt.Key_Escape)
            compare(header.threadName, "Remote name")
        }

        function test_navigationAndPermissionLossCancelDraft() {
            edit("Draft")
            header.threadId = "different"
            compare(header.editing, false)
            header.beginEditing()
            header.canEdit = false
            compare(header.editing, false)
            header.beginEditing()
            compare(header.editing, false)
            compare(findChild(header, "threadHeaderMenuButton").visible, true)
            compare(renameSpy.count, 0)
        }

        function test_menuRequestsEditingWithoutStartingInlineEditor() {
            mouseClick(findChild(header, "threadHeaderMenuButton"))
            const menu = findChild(header, "threadHeaderContextMenu")
            verify(!!menu)
            tryCompare(menu, "opened", true)
            menu.actionAt(0).trigger()
            compare(editSpy.count, 1)
            compare(header.editing, false)
            menu.close()
        }

        function test_menuOnlyShowsConnectedActions_data() {
            return [
                { tag: "can rename", canEdit: true, labels: [qsTr("Edit name"), qsTr("Mark as read")] },
                { tag: "cannot rename", canEdit: false, labels: [qsTr("Mark as read")] }
            ]
        }

        function test_menuOnlyShowsConnectedActions(data) {
            header.canEdit = data.canEdit
            mouseClick(findChild(header, "threadHeaderMenuButton"))
            const menu = findChild(header, "threadHeaderContextMenu")
            verify(!!menu)
            tryCompare(menu, "opened", true)
            const labels = []
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (item.visible && item.height > 0)
                    labels.push(item.text)
            }
            compare(labels, data.labels)
            menu.close()
        }

        function test_nonAuthorCanMarkThreadAsRead() {
            header.canEdit = false
            mouseClick(findChild(header, "threadHeaderMenuButton"))
            const menu = findChild(header, "threadHeaderContextMenu")
            verify(!!menu)
            tryCompare(menu, "opened", true)
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.objectName === "threadContextMenu_markAsRead") {
                    action.trigger()
                    break
                }
            }
            compare(readSpy.count, 1)
            menu.close()
        }

        function test_imeCompositionIsNotSubmitted() {
            const input = edit("Draft")
            ime.setPreedit(input, "composition")
            compare(input.inputMethodComposing, true)
            input.accepted()
            compare(renameSpy.count, 0)
            ime.setPreedit(input, "")
            ime.commit(input, "!")
            input.accepted()
            compare(renameSpy.count, 1)
        }

        function test_unicodeDraftIsNotTruncated() {
            header.beginEditing()
            const input = findChild(header, "threadNameInput")
            input.text = "👩‍👩‍👧‍👦".repeat(50)
            input.accepted()
            compare(renameSpy.signalArguments[0][0], input.text)
            header.editFinished("name exceeds 50 characters")
            input.text += "e\u0301"
            input.accepted()
            compare(renameSpy.signalArguments[1][0], input.text)
        }
    }
}
