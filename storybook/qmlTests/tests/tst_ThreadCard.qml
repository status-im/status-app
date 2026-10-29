import QtQuick
import QtTest
import StatusQ.Core.Theme

import AppLayouts.Chat.controls

Item {
    id: root
    width: 500
    height: 300

    ListModel {
        id: participantsListModel

        Component.onCompleted: {
            for (let index = 0; index < 6; ++index) {
                append({
                    name: "Participant " + index,
                    image: "",
                    colorId: index
                })
            }
        }
    }

    Component {
        id: componentUnderTest

        ThreadCard {
            width: 420
            threadId: "thread-id"
            originalMessageId: "parent-id"
            title: "Thread title"
            messagesCount: 12
            participantsCount: 8
            participantsPreviewModel: participantsListModel
        }
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    TestCase {
        name: "ThreadCard"
        when: windowShown

        property ThreadCard controlUnderTest

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            clickedSpy.target = controlUnderTest
            clickedSpy.clear()
        }

        function test_limitsParticipantsAndShowsRemainder() {
            const repeater = findChild(controlUnderTest, "threadCardParticipantsRepeater")
            verify(!!repeater)
            compare(repeater.count, 6)

            const remainder = findChild(controlUnderTest, "threadCardRemainingParticipants")
            verify(!!remainder)
            compare(remainder.text, "+2")

            for (let index = 0; index < 6; ++index) {
                compare(findChild(controlUnderTest, "threadCardParticipantAvatar_" + index).visible, true)
            }
        }

        function test_limitsPreviewToParticipantsCount() {
            controlUnderTest.participantsCount = 3

            for (let index = 0; index < 6; ++index) {
                compare(findChild(controlUnderTest, "threadCardParticipantAvatar_" + index).visible,
                        index < controlUnderTest.participantsCount)
            }
        }

        function test_clickEmitsThreadAndParentIds() {
            mouseClick(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
            compare(clickedSpy.count, 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
        }

        function test_updatesSummaryAndReadBadge() {
            const badge = findChild(controlUnderTest, "threadCardUnreadBadge")
            const count = findChild(controlUnderTest, "threadCardMessagesCount")
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            verify(!!badge && !!count && !!preview)

            controlUnderTest.messagesCount = 13
            controlUnderTest.notificationCount = 2
            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "New reply" }
            compare(count.text, qsTr("%n message(s)", "", 13))
            compare(badge.value, 2)
            compare(badge.visible, true)
            compare(findChild(controlUnderTest, "threadCardMessageSender").text, "Alice")
            tryVerify(() => preview.text.includes("New reply"))

            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "Edited reply" }
            tryVerify(() => preview.text.includes("Edited reply"))
            verify(!preview.text.includes("New reply"))

            controlUnderTest.messagesCount = 12
            controlUnderTest.notificationCount = 0
            controlUnderTest.lastMessage = { sender: { name: "Bob" }, text: "Previous reply" }
            compare(count.text, qsTr("%n message(s)", "", 12))
            compare(badge.visible, false)
            tryVerify(() => preview.text.includes("Previous reply"))
        }

        function test_switchesToDeletedSummary() {
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            const count = findChild(controlUnderTest, "threadCardMessagesCount")
            verify(!!preview && !!count)

            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "Active reply" }
            controlUnderTest.deletedMessage = { sender: { name: "Bob" } }
            controlUnderTest.threadState = ThreadCard.State.Deleted
            compare(findChild(controlUnderTest, "threadCardMessageSender").text, "Bob")
            tryVerify(() => preview.text.includes(qsTr("deleted this thread")))
            verify(!preview.text.includes("Active reply"))
            compare(count.visible, false)

            controlUnderTest.threadState = ThreadCard.State.Active
            tryVerify(() => preview.text.includes("Active reply"))
            compare(count.visible, true)
        }

        function test_previewLayout_data() {
            const rows = []
            const cases = [
                { tag: "short", name: "Alice", text: "OK", twoRows: false },
                { tag: "medium", name: "Alice", text: "We can review these changes tomorrow morning.", twoRows: true },
                { tag: "long", name: "Alice", text: "A long message with words ".repeat(20), twoRows: true },
                { tag: "unbroken", name: "Alice", text: "W".repeat(200), twoRows: true },
                { tag: "long-name", name: "xg28gZQS5pk5UjMudU9B".repeat(4), text: "W".repeat(200), twoRows: true },
                { tag: "emoji", name: "Alice", text: "👩‍💻 hello 🌍 ".repeat(30), twoRows: true }
            ]
            for (const width of [296, 320, 420]) {
                for (const entry of cases)
                    rows.push({ tag: width + "-" + entry.tag, width: width, name: entry.name,
                                text: entry.text, twoRows: entry.twoRows })
            }
            return rows
        }

        function test_previewLayout(data) {
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            const sender = findChild(controlUnderTest, "threadCardMessageSender")
            const timestamp = findChild(controlUnderTest, "threadCardTimestamp")
            const lines = []
            preview.lineLaidOut.connect(line => {
                lines[line.number] = { x: line.x, y: line.y, width: line.width, height: line.height }
            })
            controlUnderTest.width = data.width
            controlUnderTest.lastMessage = {
                sender: { name: data.name }, text: data.text, timestamp: Date.now()
            }
            tryVerify(() => lines.length > 0 && timestamp.text.length > 0)
            compare(timestamp.width, timestamp.implicitWidth)
            verify(timestamp.visible)
            compare(timestamp.y, sender.y + (data.twoRows ? sender.height : 0))
            compare(timestamp.baselineOffset, sender.baselineOffset)
            verify(preview.lineCount <= 2)
            verify(sender.width <= sender.parent.width / 2)
            for (const line of lines) {
                if (Math.abs(preview.y + line.y - timestamp.y) < 1)
                    verify(line.x + line.width + Theme.halfPadding <= timestamp.x + 1)
            }
            verify(timestamp.y + timestamp.height <= timestamp.parent.height + 1)
            if (data.tag.endsWith("long-name"))
                verify(sender.truncated)
        }

        function test_shortNarrowCharactersAreNotCappedAtFifty() {
            controlUnderTest.lastMessage = {
                sender: { name: "A" }, text: "i".repeat(60), timestamp: Date.now()
            }
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            tryVerify(() => preview.text.includes("i".repeat(60)))
            const sender = findChild(controlUnderTest, "threadCardMessageSender")
            const timestamp = findChild(controlUnderTest, "threadCardTimestamp")
            tryCompare(timestamp, "y", sender.y)
        }

        function test_relayoutsWhenSenderOrWidthChanges() {
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            const sender = findChild(controlUnderTest, "threadCardMessageSender")
            const timestamp = findChild(controlUnderTest, "threadCardTimestamp")
            let firstLineX = -1
            preview.lineLaidOut.connect(line => {
                if (line.number === 0)
                    firstLineX = line.x
            })
            const text = "i".repeat(60)
            const time = Date.now()
            controlUnderTest.lastMessage = { sender: { name: "A" }, text: text, timestamp: time }
            tryVerify(() => firstLineX === sender.width + Theme.halfPadding)
            tryCompare(timestamp, "y", sender.y)

            controlUnderTest.lastMessage = { sender: { name: "Long sender name".repeat(5) },
                                            text: text, timestamp: time }
            tryVerify(() => sender.truncated && firstLineX === sender.width + Theme.halfPadding)
            tryCompare(timestamp, "y", sender.y + sender.height)

            controlUnderTest.lastMessage = { sender: { name: "A" }, text: text, timestamp: time }
            tryCompare(timestamp, "y", sender.y)
            controlUnderTest.width = 296
            tryCompare(timestamp, "y", sender.y + sender.height)
            controlUnderTest.width = 420
            tryCompare(timestamp, "y", sender.y)
        }

        function test_connectorTracksRowGeometry_data() {
            const rows = []
            for (const width of [320, 420]) {
                for (const padding of [8, 16, 24]) {
                    for (const deleted of [false, true]) {
                        rows.push({ tag: width + "-" + padding + "-" + deleted,
                                    width: width, padding: padding, deleted: deleted })
                    }
                }
            }
            return rows
        }

        function test_connectorTracksRowGeometry(data) {
            controlUnderTest.width = data.width
            controlUnderTest.Theme.padding = data.padding
            controlUnderTest.notificationCount = 2
            controlUnderTest.threadState = data.deleted ? ThreadCard.State.Deleted : ThreadCard.State.Active
            const row = findChild(controlUnderTest, data.deleted ? "threadCardBodyRow" : "threadCardTitleRow")
            verify(!!row)
            tryVerify(() => row.height > 0)
            tryVerify(() => {
                const center = row.mapToItem(controlUnderTest, 0, row.height / 2).y
                return Math.abs(controlUnderTest.connectorY - center) < 0.5
            })
            verify(controlUnderTest.connectorY > 0)
            verify(controlUnderTest.connectorY < controlUnderTest.height)
        }
    }
}
