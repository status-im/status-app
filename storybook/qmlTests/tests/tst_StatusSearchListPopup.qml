import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 600
    height: 400

    property bool threadsEnabled: true

    ListModel { id: chats }
    ListModel { id: threads }

    StatusSearchListPopup {
        id: popup
        directParent: root
        model: chats
        threadModel: root.threadsEnabled ? threads : null
    }

    SignalSpy {
        id: selection
        target: popup
        signalName: "selected"
    }

    TestCase {
        name: "StatusSearchListPopup"
        when: windowShown

        function row(name, chatId, threadId, archived) {
            return {
                name, chatId, threadId, archived,
                sectionId: "community",
                sectionName: "Status Community",
                parentChatName: threadId ? "General" : "",
                icon: "", color: "", colorId: 0, emoji: ""
            }
        }

        function init() {
            chats.append(row("General", "general", "", false))
            threads.append(row("Planning", "general", "open-thread", false))
            threads.append(row("Release notes", "releases", "archived-thread", true))
            popup.open()
            tryVerify(() => popup.opened)
        }

        function cleanup() {
            popup.close()
            tryVerify(() => !popup.visible)
            root.threadsEnabled = true
            chats.clear()
            threads.clear()
            selection.clear()
        }

        function test_archiveFilterAndKeyboardSelection() {
            const input = findChild(popup, "switcherSearchBox")
            const results = findChild(popup, "switcherResults")
            tryCompare(results, "count", 2)
            tryVerify(() => results.itemAtIndex(1)?.title === "Planning")

            input.text = "  "
            tryCompare(results, "count", 2)

            input.text = "Status Community"
            tryCompare(results, "count", 1)
            compare(results.itemAtIndex(0).title, "General")

            input.text = "releAse"
            tryCompare(results, "count", 1)
            tryVerify(() => results.currentItem?.title === "Release notes")
            keyClick(Qt.Key_Return)
            compare(selection.count, 1)
            compare(Array.from(selection.signalArguments[0]), ["community", "releases", "archived-thread"])

            input.text = ""
            tryCompare(results, "count", 2)
        }

        function test_chatSelectionWithoutThreadModel() {
            root.threadsEnabled = false
            const results = findChild(popup, "switcherResults")
            tryCompare(results, "count", 1)
            tryVerify(() => results.currentItem?.title === "General")
            keyClick(Qt.Key_Return)
            compare(selection.count, 1)
            compare(Array.from(selection.signalArguments[0]), ["community", "general", ""])
        }

        function test_threadUpdatesAndMouseSelection() {
            const input = findChild(popup, "switcherSearchBox")
            const results = findChild(popup, "switcherResults")
            tryCompare(results, "count", 2)

            threads.setProperty(0, "archived", true)
            tryCompare(results, "count", 1)
            threads.setProperty(0, "name", "Project kickoff")

            input.text = "kickoff"
            tryCompare(results, "count", 1)
            tryVerify(() => results.currentItem?.title === "Project kickoff")
            mouseClick(results.currentItem)
            compare(selection.count, 1)
            compare(Array.from(selection.signalArguments[0]), ["community", "general", "open-thread"])

            threads.remove(0)
            tryCompare(results, "count", 0)
            keyClick(Qt.Key_Return)
            compare(selection.count, 1)
        }
    }
}
