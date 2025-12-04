import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.helpers
import AppLayouts.ActivityCenter.panels

import Storybook
import Models

import QtModelsToolkit
import utils

SplitView {
    id: root

    Logs { id: logs }

    // Since the notifications model mock is defined as `ListModel`, once the `onAppend` happen, attachments role is converted
    // from a plain array to a submodel. That's why it cannot be defined directly on the model definition file.
    // Here it is a manual definition of the `attachments` role so that the plain array is set to the items needed.
    ObjectProxyModel {
        id: notificationsModelMock

        sourceModel: NotificationsModel{}

        delegate: QtObject {
            readonly property var attachments: {
                if (model.chatKey === "zQ3shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA") // TODO: It will be the notification type instead
                    return [
                                "https://picsum.photos/320/240?3",
                                "https://picsum.photos/320/240?4",
                                "https://picsum.photos/320/240?5",
                                "https://picsum.photos/320/240?6",
                                "https://picsum.photos/320/240?7",
                                "https://picsum.photos/320/240?8",
                                "https://picsum.photos/320/240?1"
                            ]
                else if (model.chatKey === "zQ3142hUdnpxi26rLmgdUwNxHgcbcYFW75JcSvVych58QVXXT") // TODO: It will be the notification type instead
                    return [
                                "https://picsum.photos/320/240?1",
                                "https://picsum.photos/320/240?2",
                                "https://picsum.photos/320/240?9"
                            ]

                else if (model.chatKey === "zAssshuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7Jss12") // TODO: It will be the notification type instead
                    return [
                                "https://picsum.photos/320/240?10",
                                "https://picsum.photos/320/240?9"
                            ]
                else if (model.chatKey === "zAMNAuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTXcA") // TODO: It will be the notification type instead
                    return [
                                "https://picsum.photos/320/240?11"
                            ]
                return []
            }
        }

        expectedRoles: "chatKey" // TODO: It will be the notification type instead
        exposedRoles: "attachments"
    }

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
                    property int currentActiveGroup: ActivityCenterTypes.ActivityCenterGroup.All

                    anchors.fill: parent

                    backgroundColor: parent.color

                    hasAdmin: admin.checked
                    hasMentions: mentions.checked
                    hasReplies: replies.checked
                    hasContactRequests: contactRequests.checked
                    hasMembership: membership.checked
                    activeGroup: currentActiveGroup

                    hasUnreadNotifications: unreadNotifications.checked
                    readNotificationsStatus: read.checked ? ActivityCenterTypes.ActivityCenterReadType.Read :
                                                            unread.checked ? ActivityCenterTypes.ActivityCenterReadType.Unread :
                                                                             ActivityCenterTypes.ActivityCenterReadType.All
                    notificationsModel: (noNotifications.checked || unread.checked) ? null : notificationsModelMock
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
                                                   currentActiveGroup = group
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
                text: "Type of notifications:"
                font.bold: true
            }

            CheckBox {
                id: admin
                Layout.fillWidth: true
                text: "Has admin notifications?"
            }

            CheckBox {
                id: mentions
                Layout.fillWidth: true
                text: "Has mentions notifications?"
            }

            CheckBox {
                id: replies
                Layout.fillWidth: true
                text: "Has replies notifications?"
            }

            CheckBox {
                id: contactRequests
                Layout.fillWidth: true
                text: "Has contact requests notifications?"
            }

            CheckBox {
                id: membership
                Layout.fillWidth: true
                text: "Has membership notifications?"
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
