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
        InputMethodTester { id: ime }

        function init() {
            header = createTemporaryObject(headerComponent, root)
            verify(!!header)
            renameSpy.target = header
            renameSpy.clear()
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
            compare(findChild(header, "threadHeaderMenuButton").visible, false)
            compare(renameSpy.count, 0)
        }

        function test_menuStartsEditing() {
            mouseClick(findChild(header, "threadHeaderMenuButton"))
            const menu = findChild(header, "threadHeaderContextMenu")
            verify(!!menu)
            tryCompare(menu, "opened", true)
            menu.actionAt(0).trigger()
            tryCompare(header, "editing", true)
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
