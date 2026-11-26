import QtQuick
import QtTest
import StatusQ.Controls
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

    Component {
        id: flickableContainerComponent

        Flickable {
            width: 420
            height: 200
            contentWidth: width
            contentHeight: 600

            property alias card: card

            ThreadCard {
                id: card
                y: 100
                width: parent.width
                threadId: "thread-id"
                originalMessageId: "parent-id"
                title: "Thread title"
                messagesCount: 12
                participantsCount: 8
                participantsPreviewModel: participantsListModel
            }
        }
    }

    Component {
        id: parentSecondaryActionComponent

        Item {
            width: 420
            height: 200

            property alias card: card
            property int parentSecondaryCount: 0

            ThreadCard {
                id: card
                width: parent.width
                threadId: "thread-id"
                originalMessageId: "parent-id"
                title: "Thread title"
                messagesCount: 12
                participantsCount: 8
                participantsPreviewModel: participantsListModel
            }

            StatusSecondaryActionHandler {
                onTriggered: parent.parentSecondaryCount++
            }
        }
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    SignalSpy {
        id: contextMenuSpy
        signalName: "contextMenuRequested"
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
            contextMenuSpy.target = controlUnderTest
            contextMenuSpy.clear()
        }

        function test_deletedThreadCannotBeOpened() {
            controlUnderTest.threadState = ThreadCard.State.Deleted
            controlUnderTest.deletedMessage = { sender: { name: "Admin" }, timestamp: Date.now() }
            mouseClick(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
            compare(clickedSpy.count, 0)
            const body = findChild(controlUnderTest, "threadCardMessagePreview")
            verify(body.text.includes("deleted this thread"))
        }

        function test_mutedThreadKeepsMentionBadgeAndUsesMutedTitle() {
            controlUnderTest.muted = true
            controlUnderTest.hasUnreadMessages = true
            controlUnderTest.notificationCount = 1
            const title = findChild(controlUnderTest, "threadCardTitle")
            const badge = findChild(controlUnderTest, "threadCardUnreadBadge")
            compare(title.color, Theme.palette.directColor5)
            compare(title.font.weight, Font.Normal)
            compare(badge.visible, true)
            compare(badge.color, Theme.palette.primaryColor2)
            controlUnderTest.notificationCount = 0
            compare(badge.visible, false)
            controlUnderTest.muted = false
            compare(badge.visible, true)
            compare(badge.value, 0)
            compare(badge.color, Theme.palette.baseColor1)
            compare(title.color, Theme.palette.directColor1)
            compare(title.font.weight, Font.DemiBold)
        }

        function test_previewShowsMentionDisplayName() {
            const key = "0x04" + "a".repeat(128)
            controlUnderTest.lastMessage = { sender: { name: "Bob" }, text: "Hello @" + key + "!" }
            controlUnderTest.lastMessageMentionsMap = { [key]: "Alice" }

            const preview = findChild(controlUnderTest, "threadCardMessagePreview")
            compare(preview.text, "Hello @Alice!")
            compare(preview.textFormat, Text.PlainText)

            controlUnderTest.lastMessageMentionsMap = { [key]: "Alice Smith" }
            compare(preview.text, "Hello @Alice Smith!")
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

        function test_rightClickRequestsContextMenu() {
            mouseClick(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2, Qt.RightButton)
            tryCompare(contextMenuSpy, "count", 1)
        }

        function test_touchLongPressRequestsContextMenu() {
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, x, y).commit()
            wait(1000)
            touch.release(0, controlUnderTest, x, y).commit()
            tryCompare(contextMenuSpy, "count", 1)
            compare(clickedSpy.count, 0)
        }

        function test_touchTapEmitsThreadAndParentIds() {
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, x, y).commit()
            touch.release(0, controlUnderTest, x, y).commit()
            tryCompare(clickedSpy, "count", 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
            compare(contextMenuSpy.count, 0)
        }

        function test_touchTapChildAreas_data() {
            return [
                { tag: "title", objectName: "threadCardTitle" },
                { tag: "messages-count", objectName: "threadCardMessagesCount" },
                { tag: "message-preview", objectName: "threadCardMessagePreview" },
                { tag: "participant-avatar", objectName: "threadCardParticipantAvatar_0" }
            ]
        }

        function test_touchTapChildAreas(data) {
            controlUnderTest.lastMessage = { sender: { name: "Alice" }, text: "Reply text", timestamp: Date.now() }
            const child = findChild(controlUnderTest, data.objectName)
            verify(!!child, "Object exists")
            tryVerify(() => child.visible && child.width > 0 && child.height > 0)

            const center = child.mapToItem(controlUnderTest, child.width / 2, child.height / 2)
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, center.x, center.y).commit()
            touch.release(0, controlUnderTest, center.x, center.y).commit()
            tryCompare(clickedSpy, "count", 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
            compare(contextMenuSpy.count, 0)
        }

        function test_touchTapWithSmallJitterEmitsClicked() {
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, x, y).commit()
            touch.move(0, controlUnderTest, x + 2, y + 2).commit()
            touch.release(0, controlUnderTest, x + 2, y + 2).commit()
            tryCompare(clickedSpy, "count", 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
            compare(contextMenuSpy.count, 0)
        }

        function test_touchDragBeyondThresholdCancelsTap() {
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, x, y).commit()
            touch.move(0, controlUnderTest, x, y + 50).commit()
            touch.release(0, controlUnderTest, x, y + 50).commit()
            compare(clickedSpy.count, 0)
            compare(contextMenuSpy.count, 0)
        }

        function test_touchDeletedThreadCannotBeOpenedOrContextMenu() {
            controlUnderTest.threadState = ThreadCard.State.Deleted
            controlUnderTest.deletedMessage = { sender: { name: "Admin" }, timestamp: Date.now() }
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2

            const tap = touchEvent(controlUnderTest)
            tap.press(0, controlUnderTest, x, y).commit()
            tap.release(0, controlUnderTest, x, y).commit()
            compare(clickedSpy.count, 0)
            compare(contextMenuSpy.count, 0)

            const longPress = touchEvent(controlUnderTest)
            longPress.press(0, controlUnderTest, x, y).commit()
            wait(1000)
            longPress.release(0, controlUnderTest, x, y).commit()
            compare(clickedSpy.count, 0)
            compare(contextMenuSpy.count, 0)
        }

        function test_touchDisabledThreadCannotBeOpened() {
            controlUnderTest.enabled = false
            const x = controlUnderTest.width / 2
            const y = controlUnderTest.height / 2
            const touch = touchEvent(controlUnderTest)
            touch.press(0, controlUnderTest, x, y).commit()
            touch.release(0, controlUnderTest, x, y).commit()
            compare(clickedSpy.count, 0)
            compare(contextMenuSpy.count, 0)
        }

        function test_touchTapInsideFlickable() {
            const flickable = createTemporaryObject(flickableContainerComponent, root)
            verify(!!flickable, "Component exists")
            const card = flickable.card
            clickedSpy.target = card
            clickedSpy.clear()
            contextMenuSpy.target = card
            contextMenuSpy.clear()

            const x = card.width / 2
            const y = card.height / 2
            const touch = touchEvent(card)
            touch.press(0, card, x, y).commit()
            touch.release(0, card, x, y).commit()
            tryCompare(clickedSpy, "count", 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
            compare(contextMenuSpy.count, 0)
        }

        function test_touchScrollInsideFlickableCancelsTap() {
            const flickable = createTemporaryObject(flickableContainerComponent, root)
            verify(!!flickable, "Component exists")
            const card = flickable.card
            clickedSpy.target = card
            clickedSpy.clear()
            contextMenuSpy.target = card
            contextMenuSpy.clear()

            const startX = card.width / 2
            const startY = card.y + card.height / 2
            const touch = touchEvent(flickable)
            touch.press(0, flickable, startX, startY).commit()
            for (let step = 1; step <= 8; ++step) {
                touch.move(0, flickable, startX, startY - step * 12).commit()
                wait(16)
            }
            touch.release(0, flickable, startX, startY - 96).commit()

            tryVerify(() => flickable.contentY > 0)
            compare(clickedSpy.count, 0)
            compare(contextMenuSpy.count, 0)
        }

        function test_touchTapUnderParentSecondaryActionHandler() {
            const container = createTemporaryObject(parentSecondaryActionComponent, root)
            verify(!!container, "Component exists")
            const card = container.card
            clickedSpy.target = card
            clickedSpy.clear()
            contextMenuSpy.target = card
            contextMenuSpy.clear()

            const x = card.width / 2
            const y = card.height / 2
            const touch = touchEvent(card)
            touch.press(0, card, x, y).commit()
            touch.release(0, card, x, y).commit()
            tryCompare(clickedSpy, "count", 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
            compare(contextMenuSpy.count, 0)
            compare(container.parentSecondaryCount, 0)
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
            compare(badge.color, Theme.palette.primaryColor1)
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
