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

        function test_titleDisplaysMarkupLiterally() {
            const name = "<b>Bold</b> & <a href='https://example.com'>link</a>"
            controlUnderTest.title = name

            const title = findChild(controlUnderTest, "threadCardTitle")
            verify(!!title)
            compare(title.text, name)
            compare(title.textFormat, Text.PlainText)
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
            verify(preview.text.includes("Alice"))
            verify(preview.text.includes("New reply"))

            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "Edited reply" }
            verify(preview.text.includes("Edited reply"))
            verify(!preview.text.includes("New reply"))

            controlUnderTest.messagesCount = 12
            controlUnderTest.notificationCount = 0
            controlUnderTest.lastMessage = { sender: { name: "Bob" }, text: "Previous reply" }
            compare(count.text, qsTr("%n message(s)", "", 12))
            compare(badge.visible, false)
            verify(preview.text.includes("Previous reply"))
        }

        function test_switchesToDeletedSummary() {
            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            const count = findChild(controlUnderTest, "threadCardMessagesCount")
            verify(!!preview && !!count)

            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "Active reply" }
            controlUnderTest.deletedMessage = { sender: { name: "Bob" } }
            controlUnderTest.threadState = ThreadCard.State.Deleted
            verify(preview.text.includes("Bob"))
            verify(preview.text.includes(qsTr("deleted this thread")))
            verify(!preview.text.includes("Active reply"))
            compare(count.visible, false)

            controlUnderTest.threadState = ThreadCard.State.Active
            verify(preview.text.includes("Active reply"))
            compare(count.visible, true)
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
