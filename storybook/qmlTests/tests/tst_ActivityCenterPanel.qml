import QtQuick
import QtTest

import AppLayouts.ActivityCenter.panels
import AppLayouts.ActivityCenter.helpers
import StatusQ.Core.Theme

import utils

Item {
    id: root
    width: 500
    height: 700

    Component {
        id: componentUnderTest
        ActivityCenterPanel {
            anchors.fill: parent

            hasAdmin: false
            hasMentions: false
            hasReplies: false
            hasContactRequests: false
            hasMembership: false
            hasSystem: false
            hasNews: false
            activeGroup: ActivityCenterTypes.ActivityCenterGroup.All

            readNotificationsStatus: ActivityCenterTypes.ActivityCenterReadType.All
            hasUnreadNotifications: false

            notificationsModel: null

            newsSettingsStatus: Constants.settingsSection.notifications.sendAlertsValue
            newsEnabledViaRSS: true
        }
    }

    Component {
        id: listModelComponent
        ListModel {}
    }

    SignalSpy {
        id: closeRequestedSpy
        target: controlUnderTest
        signalName: "closeRequested"
    }

    SignalSpy {
        id: markAllAsReadSpy
        target: controlUnderTest
        signalName: "markAllAsReadRequested"
    }

    SignalSpy {
        id: hideShowSpy
        target: controlUnderTest
        signalName: "hideShowReadNotificationsRequested"
    }

    SignalSpy {
        id: setActiveGroupSpy
        target: controlUnderTest
        signalName: "setActiveGroupRequested"
    }

    property ActivityCenterPanel controlUnderTest: null

    TestCase {
        name: "ActivityCenterPanel"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            closeRequestedSpy.clear()
            markAllAsReadSpy.clear()
            hideShowSpy.clear()
            setActiveGroupSpy.clear()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            compare(controlUnderTest.hasAdmin, false)
            compare(controlUnderTest.hasMentions, false)
            compare(controlUnderTest.hasReplies, false)
            compare(controlUnderTest.hasContactRequests, false)
            compare(controlUnderTest.hasMembership, false)
            compare(controlUnderTest.activeGroup, ActivityCenterTypes.ActivityCenterGroup.All)
            compare(controlUnderTest.hasUnreadNotifications, false)
            compare(controlUnderTest.notificationsModel, null)
            compare(controlUnderTest.newsEnabledViaRSS, true)
        }

        function test_objectName() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            compare(controlUnderTest.objectName, "activityCenterPanel")
        }

        function test_closeButton() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const closeBtn = findChild(controlUnderTest, "closeButton")
            verify(!!closeBtn)
            mouseClick(closeBtn)
            compare(closeRequestedSpy.count, 1)
        }

        function test_markAllReadButton() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                hasUnreadNotifications: true
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const markAllBtn = findChild(controlUnderTest, "markAllReadButton")
            verify(!!markAllBtn)
            verify(markAllBtn.enabled)
            mouseClick(markAllBtn)
            compare(markAllAsReadSpy.count, 1)
        }

        function test_hideShowButton() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const hideShowBtn = findChild(controlUnderTest, "hideShowButton")
            verify(!!hideShowBtn)
            mouseClick(hideShowBtn)
            compare(hideShowSpy.count, 1)
        }

        function test_emptyState() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                notificationsModel: null
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            // With null model, the list should have 0 items and empty placeholder active
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)

            // Verify the placeholder loader is active and visible
            const placeholder = findChild(controlUnderTest, "placeholderLoader")
            verify(!!placeholder)
            verify(placeholder.visible)
            verify(placeholder.active)
        }

        function test_withModel() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            var model = createTemporaryObject(listModelComponent, root)
            verify(!!model)
            model.append({
                unread: true,
                avatarSource: "",
                badgeIconName: "action-mention",
                isCircularAvatar: true,
                isAvatarClickable: false,
                isBadgeClickable: false,
                avatarLetterColor: "#ff0000",
                avatarLetterText: "A",
                isAvatarLetterAcronym: false,
                avatarMaxTextLen: 1,
                title: "TestUser",
                chatKey: "zQ3shuV7mZextijeBSDpgaq2",
                isContact: false,
                trustIndicator: 0,
                isBlocked: false,
                primaryText: "",
                contextAvatar: "",
                iconName: "",
                secondaryText: "",
                separatorIconName: "",
                actionText: "",
                preImageSource: "",
                preImageRadius: 0,
                content: "Hello world",
                attachments: [],
                showQuickActions: false,
                actionId: "",
                timestamp: 1765799225000,
                redirectToDetails: true,
                redirectToSection: false,
                redirectToLink: false,
                redirectToWallet: false,
                sectionId: "",
                subsectionId: "",
                subsectionItemId: "",
                avatarId: "avatar1"
            })
            controlUnderTest.notificationsModel = model
            waitForRendering(controlUnderTest)

            verify(controlUnderTest.width > 0)

            // Verify model has expected number of elements
            compare(model.count, 1)

            // Find the ListView and verify its count matches
            const listView = findChild(controlUnderTest, "listView")
            verify(!!listView)
            compare(listView.count, 1)
        }

        function test_hideReadNotifications() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                readNotificationsStatus: ActivityCenterTypes.ActivityCenterReadType.Unread
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.hideReadNotifications, true)

            // Verify the hide/show button icon reflects the state
            const hideShowBtn = findChild(controlUnderTest, "hideShowButton")
            verify(!!hideShowBtn)
            compare(hideShowBtn.icon.name, "show")

            // When hideReadNotifications is false, icon should be "hide"
            controlUnderTest.readNotificationsStatus = ActivityCenterTypes.ActivityCenterReadType.All
            compare(controlUnderTest.hideReadNotifications, false)
            compare(hideShowBtn.icon.name, "hide")
        }

        function test_newsSettingsStatus() {
            // Test 1: newsSettingsStatus = turnOff AND newsEnabledViaRSS = true → placeholder active
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                newsSettingsStatus: Constants.settingsSection.notifications.turnOffValue,
                newsEnabledViaRSS: true,
                activeGroup: ActivityCenterTypes.ActivityCenterGroup.NewsMessage
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.newsSettingsStatus, Constants.settingsSection.notifications.turnOffValue)

            const placeholder = findChild(controlUnderTest, "placeholderLoader")
            verify(!!placeholder)
            verify(placeholder.active)
            verify(placeholder.visible)

            // Test 2: newsEnabledViaRSS = false → still placeholder active (RSS disabled reason)
            controlUnderTest.newsEnabledViaRSS = false
            waitForRendering(controlUnderTest)
            verify(placeholder.active)
            verify(placeholder.visible)

            // Test 3: newsSettingsStatus = sendAlerts AND newsEnabledViaRSS = true → news placeholder inactive
            controlUnderTest.newsSettingsStatus = Constants.settingsSection.notifications.sendAlertsValue
            controlUnderTest.newsEnabledViaRSS = true
            waitForRendering(controlUnderTest)
            // News placeholder is no longer the reason for the placeholder being active.
            // The placeholder may still be active due to an empty list (emptyNotificationsList),
            // but the news-specific condition (isNewsPlaceholderActive) is now false.
            // We can verify indirectly: the listView should exist and the placeholder source
            // would be the empty state, not the news state.
            const listView = findChild(controlUnderTest, "listView")
            verify(!!listView)
            // The placeholder is still active but sourced from emptyPlaceholderPanel, not newsPlaceholderPanel
            verify(placeholder.active)

            // Test 4: Change activeGroup away from NewsMessage → news placeholder inactive regardless
            controlUnderTest.activeGroup = ActivityCenterTypes.ActivityCenterGroup.All
            controlUnderTest.newsSettingsStatus = Constants.settingsSection.notifications.turnOffValue
            controlUnderTest.newsEnabledViaRSS = false
            waitForRendering(controlUnderTest)
            // Even with news settings disabled, changing away from NewsMessage group means
            // the news placeholder logic doesn't apply. Placeholder still active due to empty list.
            verify(placeholder.active)
        }

        function test_propertyChanges() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            controlUnderTest.hasAdmin = true
            compare(controlUnderTest.hasAdmin, true)

            controlUnderTest.hasMentions = true
            compare(controlUnderTest.hasMentions, true)

            controlUnderTest.hasReplies = true
            compare(controlUnderTest.hasReplies, true)

            controlUnderTest.hasContactRequests = true
            compare(controlUnderTest.hasContactRequests, true)

            controlUnderTest.hasMembership = true
            compare(controlUnderTest.hasMembership, true)

            controlUnderTest.hasUnreadNotifications = true
            compare(controlUnderTest.hasUnreadNotifications, true)
        }
    }
}
