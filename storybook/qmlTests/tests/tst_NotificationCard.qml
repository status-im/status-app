import QtQuick
import QtTest

import AppLayouts.ActivityCenter.controls
import StatusQ.Core.Theme

import utils

Item {
    id: root
    width: 600
    height: 600

    Component {
        id: componentUnderTest
        NotificationCard {
            anchors.centerIn: parent
            width: 400
        }
    }

    SignalSpy {
        id: clickedSpy
        target: controlUnderTest
        signalName: "clicked"
    }

    SignalSpy {
        id: avatarClickedSpy
        target: controlUnderTest
        signalName: "avatarClicked"
    }

    SignalSpy {
        id: declineRequestedSpy
        target: controlUnderTest
        signalName: "declineRequested"
    }

    SignalSpy {
        id: acceptRequestedSpy
        target: controlUnderTest
        signalName: "acceptRequested"
    }

    SignalSpy {
        id: markAsReadRequestedSpy
        target: controlUnderTest
        signalName: "markAsReadRequested"
    }

    SignalSpy {
        id: markAsUnreadRequestedSpy
        target: controlUnderTest
        signalName: "markAsUnreadRequested"
    }

    property NotificationCard controlUnderTest: null

    TestCase {
        name: "NotificationCard"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            clickedSpy.clear()
            avatarClickedSpy.clear()
            declineRequestedSpy.clear()
            acceptRequestedSpy.clear()
            markAsReadRequestedSpy.clear()
            markAsUnreadRequestedSpy.clear()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            // Avatar
            compare(controlUnderTest.avatarSource.toString(), "")
            compare(controlUnderTest.badgeIconName.toString(), "")
            compare(controlUnderTest.isCircularAvatar, true)
            compare(controlUnderTest.isAvatarClickable, false)
            compare(controlUnderTest.isBadgeClickable, false)
            compare(controlUnderTest.avatarLetterText, "")
            compare(controlUnderTest.isAvatarLetterAcronym, false)
            compare(controlUnderTest.avatarMaxTextLen, 1)

            // Header
            compare(controlUnderTest.title, "")
            compare(controlUnderTest.chatKey, "")
            compare(controlUnderTest.isContact, false)
            compare(controlUnderTest.trustIndicator, 0)
            compare(controlUnderTest.isBlocked, false)

            // Action/content
            compare(controlUnderTest.actionText, "")
            compare(controlUnderTest.timestamp, 0)
            compare(controlUnderTest.content, "")
            compare(controlUnderTest.preImageRadius, 0)

            // States
            compare(controlUnderTest.unread, false)
            compare(controlUnderTest.actionId, "")
        }

        function test_objectName() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            compare(controlUnderTest.objectName, "notificationCard")
        }

        function test_minimalCard() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice",
                content: "sent you a message"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.title, "Alice")
            compare(controlUnderTest.content, "sent you a message")
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_unreadState_data() {
            return [
                { tag: "read", unread: false },
                { tag: "unread", unread: true },
            ]
        }

        function test_unreadState(data) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                unread: data.unread
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.unread, data.unread)

            // The unread indicator is inside background. Verify via findChild.
            const indicator = findChild(controlUnderTest, "notificationReadIndicator")
            if (indicator)
                compare(indicator.visible, data.unread)
        }

        function test_headerVisibility() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            // Header is visible when title is non-empty
            const header = findChild(controlUnderTest, "notificationHeader")
            verify(!!header)
            compare(header.visible, true)

            // Header hides when title is cleared
            controlUnderTest.title = ""
            compare(header.visible, false)
        }

        function test_contextRowVisibility() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice",
                primaryText: "CryptoPunks"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const context = findChild(controlUnderTest, "notificationContext")
            verify(!!context)
            compare(context.visible, true)

            controlUnderTest.primaryText = ""
            compare(context.visible, false)
        }

        function test_actionTextVisibility() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice",
                actionText: "New contact request"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const actionText = findChild(controlUnderTest, "notificationActionText")
            verify(!!actionText)
            compare(actionText.visible, true)
            compare(actionText.text, "New contact request")

            controlUnderTest.actionText = ""
            compare(actionText.visible, false)
        }

        function test_fullNotification() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "anna.eth",
                chatKey: "zQ3shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA",
                isContact: true,
                trustIndicator: 1,
                isBlocked: false,
                primaryText: "CryptoPunks",
                secondaryText: "#design",
                iconName: "communities",
                separatorIconName: "arrow-next",
                content: "Hey, check this out!",
                actionText: "Mentioned you",
                unread: true,
                timestamp: 1765799225000
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.title, "anna.eth")
            compare(controlUnderTest.isContact, true)
            compare(controlUnderTest.trustIndicator, 1)
            compare(controlUnderTest.unread, true)
            compare(controlUnderTest.content, "Hey, check this out!")
            compare(controlUnderTest.primaryText, "CryptoPunks")
            compare(controlUnderTest.secondaryText, "#design")
        }

        function test_selectedState() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                selected: false
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.selected, false)
            controlUnderTest.selected = true
            compare(controlUnderTest.selected, true)
        }

        function test_quickActionsVisibility() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                actionId: ""
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            // Quick actions row hidden when actionId is empty
            const quickActions = findChild(controlUnderTest, "quickActions")
            verify(!!quickActions)
            compare(quickActions.visible, false)

            // Quick actions row visible when actionId is non-empty
            controlUnderTest.actionId = "some-action-id"
            compare(quickActions.visible, true)

            // Verify buttons are findable when quick actions are shown
            const declineBtn = findChild(controlUnderTest, "notificationDeclineBtn")
            verify(!!declineBtn)
            const acceptBtn = findChild(controlUnderTest, "notificationAcceptBtn")
            verify(!!acceptBtn)

            // Quick actions hide again when actionId is cleared
            controlUnderTest.actionId = ""
            compare(quickActions.visible, false)
        }

        function test_avatarProperties() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                isCircularAvatar: false,
                isAvatarClickable: true,
                isBadgeClickable: true,
                avatarLetterText: "AB",
                isAvatarLetterAcronym: true,
                avatarMaxTextLen: 2
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.isCircularAvatar, false)
            compare(controlUnderTest.isAvatarClickable, true)
            compare(controlUnderTest.isBadgeClickable, true)
            compare(controlUnderTest.avatarLetterText, "AB")
            compare(controlUnderTest.isAvatarLetterAcronym, true)
            compare(controlUnderTest.avatarMaxTextLen, 2)

            // The internal NotificationAvatar should be findable
            const avatar = findChild(controlUnderTest, "notificationAvatar")
            verify(!!avatar)
        }

        function test_timestampDisplay() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                timestamp: 1765799225000
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.timestamp, 1765799225000)

            const timestampText = findChild(controlUnderTest, "notificationTimestamp")
            verify(!!timestampText)
            verify(timestampText.text !== "")
        }

        function test_clickSignal() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(clickedSpy.count, 0)
            mouseClick(controlUnderTest)
            compare(clickedSpy.count, 1)
        }

        function test_avatarClickSignal() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                isAvatarClickable: true,
                avatarLetterText: "A"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(avatarClickedSpy.count, 0)
            const avatar = findChild(controlUnderTest, "notificationAvatar")
            verify(!!avatar)
            mouseClick(avatar)
            compare(avatarClickedSpy.count, 1)
        }

        function test_quickActionSignals() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                actionId: "test-action-id"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)

            const declineBtn = findChild(controlUnderTest, "notificationDeclineBtn")
            verify(!!declineBtn)
            verify(declineBtn.visible)
            compare(declineRequestedSpy.count, 0)
            mouseClick(declineBtn)
            compare(declineRequestedSpy.count, 1)

            const acceptBtn = findChild(controlUnderTest, "notificationAcceptBtn")
            verify(!!acceptBtn)
            verify(acceptBtn.visible)
            compare(acceptRequestedSpy.count, 0)
            mouseClick(acceptBtn)
            compare(acceptRequestedSpy.count, 1)
        }

        function rightClickCenter(item) {
            mouseClick(item, item.width / 2, item.height / 2, Qt.RightButton)
        }

        function waitForContextMenuOpen(card) {
            const panel = findChild(card, "notificationContextPanel")
            verify(!!panel)
            tryVerify(() => panel.height >= panel.expandedHeight - 1)
        }

        function waitForContextMenuClosed(card) {
            const panel = findChild(card, "notificationContextPanel")
            verify(!!panel)
            tryVerify(() => panel.height === 0)
        }

        function test_markAsUnreadContextMenu() {
            // Card is read (unread: false) → button says "Mark as unread"
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                unread: false
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const btn = findChild(controlUnderTest, "notificationMarkUnreadBtn")
            verify(!!btn)
            verify(!btn.visible)

            rightClickCenter(controlUnderTest)
            waitForContextMenuOpen(controlUnderTest)
            compare(btn.text, qsTr("Mark as unread"))

            compare(markAsUnreadRequestedSpy.count, 0)
            mouseClick(btn)
            compare(markAsUnreadRequestedSpy.count, 1)
            compare(markAsReadRequestedSpy.count, 0)
            waitForContextMenuClosed(controlUnderTest)
        }

        function test_markAsReadContextMenu() {
            // Card is unread (unread: true) → button says "Mark as read"
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test",
                unread: true
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const btn = findChild(controlUnderTest, "notificationMarkUnreadBtn")
            verify(!!btn)

            rightClickCenter(controlUnderTest)
            waitForContextMenuOpen(controlUnderTest)
            compare(btn.text, qsTr("Mark as read"))

            compare(markAsReadRequestedSpy.count, 0)
            mouseClick(btn)
            compare(markAsReadRequestedSpy.count, 1)
            compare(markAsUnreadRequestedSpy.count, 0)
            waitForContextMenuClosed(controlUnderTest)
        }

        function test_contextMenuClosesOnLeftClick() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const btn = findChild(controlUnderTest, "notificationMarkUnreadBtn")
            verify(!!btn)

            // Open context menu via right-click
            rightClickCenter(controlUnderTest)
            waitForContextMenuOpen(controlUnderTest)

            // Left-click on the card closes the menu without emitting clicked()
            const cardBg = findChild(controlUnderTest, "notificationCardBg")
            verify(!!cardBg)
            mouseClick(cardBg)
            waitForContextMenuClosed(controlUnderTest)
            compare(clickedSpy.count, 0)
        }
    }
}
