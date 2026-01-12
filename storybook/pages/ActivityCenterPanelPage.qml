import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.helpers
import AppLayouts.ActivityCenter.panels

import Storybook
import Models

import SortFilterProxyModel
import QtModelsToolkit
import utils

SplitView {
    id: root

    property int currentActiveGroup: ActivityCenterTypes.ActivityCenterGroup.All

    Logs { id: logs }

    // Here the complete list of notifications
    NotificationsModel {
        id: allNotificationsModelMock
    }

    // *** Simple adaptors to simulate filter entries according to a selected categroy
    SortFilterProxyModel {
        id: adminMock
        sourceModel: allNotificationsModelMock
        filters: [
            AnyOf {
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.OwnerTokenReceived
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.OwnershipReceived
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.OwnershipLost
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.OwnershipFailed
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.OwnershipDeclined
                }
            }
        ]
    }

    SortFilterProxyModel {
        id: mentionsMock
        sourceModel: allNotificationsModelMock
        filters: [
            ValueFilter {
                roleName: "notificationType"
                value: ActivityCenterTypes.NotificationType.Mention
            }
        ]
    }

    SortFilterProxyModel {
        id: repliesMock
        sourceModel: allNotificationsModelMock
        filters: [
            ValueFilter {
                roleName: "notificationType"
                value: ActivityCenterTypes.NotificationType.Reply
            }
        ]
    }

    SortFilterProxyModel {
        id: contactRequestsMock
        sourceModel: allNotificationsModelMock
        filters: [
            AnyOf {
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.ContactRequest
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.ContactRemoved
                }
            }
        ]
    }

    SortFilterProxyModel {
        id: membershipMock
        sourceModel: allNotificationsModelMock
        filters: [
            AnyOf {
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityInvitation
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityMembershipRequest
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityRequest
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityKicked
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityTokenReceived
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.FirstCommunityTokenReceived
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityBanned
                }
                ValueFilter {
                    roleName: "notificationType"
                    value: ActivityCenterTypes.NotificationType.CommunityUnbanned
                }
            }
        ]
    }

    SortFilterProxyModel {
        id: newsMock
        sourceModel: allNotificationsModelMock
        filters: [
            ValueFilter {
                roleName: "notificationType"
                value: ActivityCenterTypes.NotificationType.ActivityCenterNotificationTypeNews
            }
        ]
    }

    function getNotificationsModelMock() {
        switch (root.currentActiveGroup) {
        case ActivityCenterTypes.ActivityCenterGroup.Admin:
            return adminMock

        case ActivityCenterTypes.ActivityCenterGroup.Mentions:
            return mentionsMock

        case ActivityCenterTypes.ActivityCenterGroup.Replies:
            return repliesMock

        case ActivityCenterTypes.ActivityCenterGroup.ContactRequests:
            return contactRequestsMock

        case ActivityCenterTypes.ActivityCenterGroup.Membership:
            return membershipMock

        case ActivityCenterTypes.ActivityCenterGroup.NewsMessage:
            return newsMock
        }
        return allNotificationsModelMock
    }
    // ***

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            color: Theme.palette.baseColor4

            Rectangle {
                color: Theme.palette.baseColor2
                radius: 12
                anchors.centerIn: parent
                width: slider.value
                height: sliderHeight.value

                ActivityCenterPanel {
                    anchors.fill: parent

                    backgroundColor: parent.color

                    hasAdmin: adminMock.count > 0
                    hasMentions: mentionsMock.count > 0
                    hasReplies: repliesMock.count > 0
                    hasContactRequests: contactRequestsMock.count > 0
                    hasMembership: membershipMock.count > 0
                    activeGroup: root.currentActiveGroup

                    hasUnreadNotifications: unreadNotifications.checked
                    readNotificationsStatus: read.checked ? ActivityCenterTypes.ActivityCenterReadType.Read :
                                                            unread.checked ? ActivityCenterTypes.ActivityCenterReadType.Unread :
                                                                             ActivityCenterTypes.ActivityCenterReadType.All
                    notificationsModel: (noNotifications.checked || unread.checked) ? null : getNotificationsModelMock()
                    newsSettingsStatus: newsSettingsTurnOff.checked ? Constants.settingsSection.notifications.turnOffValue : Constants.settingsSection.notifications.sendAlertsValue
                    newsEnabledViaRSS: enabledViaRSS.checked

                    onMoreOptionsRequested: logs.logEvent("ActivityCenterPanel::onMoreOptionsRequested")
                    onCloseRequested: logs.logEvent("ActivityCenterPanel::onCloseRequested")
                    onMarkAllAsReadRequested: {
                        logs.logEvent("ActivityCenterPanel::onMarkAllAsReadRequested")
                        unreadNotifications.checked = false
                    }
                    onHideShowReadNotificationsRequested: {
                        logs.logEvent("ActivityCenterPanel::onHideShowReadNotificationsRequested: " + hideReadNotifications)
                        if(hideReadNotifications)
                            read.checked = true
                        else
                            unread.checked = true
                    }
                    onSetActiveGroupRequested: (group) => {
                                                   logs.logEvent("ActivityCenterPanel::onSetActiveGroupRequested: " + group)
                                                   root.currentActiveGroup = group
                                               }
                    onNotificationClicked: (index) => logs.logEvent("ActivityCenterPanel::onNotificationClicked: " + index)
                    onFetchMoreNotificationsRequested: logs.logEvent("ActivityCenterPanel::onFetchMoreNotificationsRequested")
                    onEnableNewsViaRSSRequested: {
                        logs.logEvent("ActivityCenterPanel::onEnableNewsViaRSSRequested")
                        enabledViaRSS.checked = !enabledViaRSS.checked
                    }
                    onEnableNewsRequested: {
                        logs.logEvent("ActivityCenterPanel::onEnableNewsRequested")
                        newsSettingsTurnOff.checked = !newsSettingsTurnOff.checked
                    }
                }
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: "Panel dynamic width:"
                font.bold: true
            }
            Slider {
                id: slider
                Layout.fillWidth: true
                value: 368
                from: 250
                to: 600
            }

            Label {
                Layout.fillWidth: true
                text: "Panel dynamic height:"
                font.bold: true
            }
            Slider {
                id: sliderHeight
                Layout.fillWidth: true
                value: 650
                from: 400
                to: 800
            }

            Label {
                Layout.fillWidth: true
                text: "News Feed Settings"
                font.bold: true
            }

            CheckBox {
                id: newsSettingsTurnOff
                Layout.fillWidth: true
                text: "Turn Off Settings"
            }

            CheckBox {
                id: enabledViaRSS
                Layout.fillWidth: true
                text: "Enabled Via RSS?"
            }

            Label {
                Layout.fillWidth: true
                text: "Read Status"
                font.bold: true
            }

            RadioButton {
                id: read
                text: "Read"
                checked: true
            }
            RadioButton {
                id: unread
                text: "Unread"
            }
            RadioButton {
                id: noNotifications
                text: "No notifications"
            }

            CheckBox {
                id: unreadNotifications
                Layout.fillWidth: true
                text: "Has unread nontificaitons?"
                checked: true
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1868-52013&m=dev
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1902-48455&m=dev
