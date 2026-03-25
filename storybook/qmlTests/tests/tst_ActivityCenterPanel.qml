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
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const markAllBtn = findChild(controlUnderTest, "markAllReadButton")
            verify(!!markAllBtn)
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
        }

        function test_hideReadNotifications() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                readNotificationsStatus: ActivityCenterTypes.ActivityCenterReadType.Unread
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.hideReadNotifications, true)

            controlUnderTest.readNotificationsStatus = ActivityCenterTypes.ActivityCenterReadType.All
            compare(controlUnderTest.hideReadNotifications, false)
        }

        function test_newsSettingsStatus() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                newsSettingsStatus: Constants.settingsSection.notifications.turnOffValue,
                newsEnabledViaRSS: true,
                activeGroup: ActivityCenterTypes.ActivityCenterGroup.NewsMessage
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.newsSettingsStatus, Constants.settingsSection.notifications.turnOffValue)
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
