import QtQuick
import QtQuick.Controls
import QtQuick.Layouts


import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure

import StatusQ

import AppLayouts.ActivityCenter.controls
import AppLayouts.ActivityCenter.helpers

import utils

Control {
    id: root

    // Properties related to the different notification types / groups:
    required property bool hasAdmin
    required property bool hasMentions
    required property bool hasReplies
    required property bool hasContactRequests
    required property bool hasMembership
    required property int activeGroup

    // Properties related to notifications states:
    required property int readNotificationsStatus
    required property bool hasUnreadNotifications
    readonly property bool hideReadNotifications: root.readNotificationsStatus === ActivityCenterTypes.ActivityCenterReadType.Unread
    required property var notificationsModel

    // Properties related to news feed settings:
    required property string newsSettingsStatus
    required property bool newsEnabledViaRSS

    // Style:
    property color backgroundColor: Theme.palette.baseColor2

    signal moreOptionsRequested()
    signal closeRequested()
    signal markAllAsReadRequested()
    signal hideShowReadNotificationsRequested()
    signal setActiveGroupRequested(int group)
    signal notificationClicked(int index)
    signal fetchMoreNotificationsRequested()
    signal enableNewsViaRSSRequested()
    signal enableNewsRequested()

    QtObject {
        id: d

        readonly property bool emptyNotificationsList: listView.count === 0
        readonly property bool newsDisabledBySettings: !root.newsEnabledViaRSS || root.newsSettingsStatus === Constants.settingsSection.notifications.turnOffValue
        readonly property bool isNewsPlaceholderActive: root.activeGroup === ActivityCenterTypes.ActivityCenterGroup.NewsMessage && d.newsDisabledBySettings

        property bool optionsMenuVisible: false

        readonly property var fetchMoreNotifications: Backpressure.oneInTimeQueued(root, 100, function() {
            if (listView.contentY >= listView.contentHeight - listView.height - 1) {
                root.fetchMoreNotificationsRequested()
            }
        })
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Panel Header
        RowLayout {
            id: panelHeader

            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.topMargin: Theme.halfPadding
            Layout.bottomMargin: Theme.halfPadding
            Layout.rightMargin: 0

            spacing: 0

            StatusNavigationPanelHeadline {
                Layout.fillWidth: true

                font.pixelSize: Theme.fontSize(19)
                text: qsTr("Notifications")
                elide: Text.ElideRight
            }

            // Filler
            Item {
                Layout.fillWidth: true
            }

            StatusFlatRoundButton {
                id: moreBtn
                objectName: "moreOptionsButton"
                icon.name: "more"
                onClicked: options.open()

                // It will be reworked on task https://github.com/status-im/status-app/issues/18906
                ActivityCenterOptionsPanel {
                    id: options

                    y: panelHeader.height
                    x: -implicitWidth + moreBtn.width

                    hasUnreadNotifications: root.hasUnreadNotifications
                    hideReadNotifications: root.hideReadNotifications

                    onMarkAllAsReadRequested: root.markAllAsReadRequested()
                    onHideShowReadNotificationsRequested: root.hideShowReadNotificationsRequested()
                    onOpened: d.optionsMenuVisible = true
                    onClosed: d.optionsMenuVisible = false
                }
            }

            StatusFlatRoundButton {
                objectName: "closeButton"
                icon.name: "close"
                onClicked: {
                    d.optionsMenuVisible = false
                    root.closeRequested()
                }
            }
        }

        // Notification's List Header
        ActivityCenterPopupTopBarPanel {
            Layout.fillWidth: true

            hasAdmin: root.hasAdmin
            hasReplies: root.hasReplies
            hasMentions: root.hasMentions
            hasContactRequests: root.hasContactRequests
            hasMembership: root.hasMembership
            activeGroup: root.activeGroup

            gradientColor: root.backgroundColor

            onSetActiveGroupRequested: (group)=> root.setActiveGroupRequested(group)
        }

        // Notifications List
        StatusListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: !d.emptyNotificationsList || !d.isNewsPlaceholderActive
            Layout.topMargin: 2

            visible: !d.emptyNotificationsList && !d.isNewsPlaceholderActive
            enabled: !d.optionsMenuVisible
            verticalScrollBar.implicitWidth: Theme.halfPadding

            spacing: 4
            implicitHeight: contentHeight
            model: root.notificationsModel
            delegate: NotificationCard {
                enabled: !d.optionsMenuVisible

                width: root.width - 2 * Theme.halfPadding
                anchors.horizontalCenter: listView.contentItem.horizontalCenter

                // Card states related
                unread: model.unread
                selected: model.selected

                // Avatar related
                avatarSource: model.avatarSource
                badgeIconName: model.badgeIconName
                isCircularAvatar: model.isCircularAvatar

                // Header row related
                title: model.title
                chatKey: model.chatKey
                isContact: model.isContact
                trustIndicator: model.trustIndicator

                // Context row related
                primaryText: model.primaryText
                iconName: model.iconName
                secondaryText: model.secondaryText
                separatorIconName: model.separatorIconName

                // Action text
                actionText: model.actionText

                // Content block related
                preImageSource: model.preImageSource
                preImageRadius: model.preImageRadius
                content: model.content
                attachments: model.attachments

                // Timestamp related
                timestamp: model.timestamp

                // Interactions
                onClicked: root.notificationClicked(model.index)
            }

            onContentYChanged: d.fetchMoreNotifications()

            // Overlay
            Rectangle {
                visible: d.optionsMenuVisible
                anchors.fill: parent
                color: root.backgroundColor
                opacity: 0.8
            }
        }

        // Placeholders in particular cases:
        // This will be reworked on: https://github.com/status-im/status-app/issues/18905
        // Placeholder for the status news when their settings are disabled
        // OR Placeholder for the status news when they are all seen or there are no notifications
        Loader {
            id: placeholderLoader


            Layout.fillWidth: true
            Layout.margins: Theme.padding
            visible: active
            active: d.isNewsPlaceholderActive || d.emptyNotificationsList

            sourceComponent: d.isNewsPlaceholderActive ? newsPlaceholderPanel : emptyPlaceholderPanel
        }

        // Filler
        Item {
            Layout.fillHeight: placeholderLoader.active || d.emptyNotificationsList
        }
    }

    // This will be reworked on: https://github.com/status-im/status-app/issues/18905
    // If !root.newsEnabledViaRSS it means the panel is for enabling RSS notification
    // Otherwise, it means it is for enabling status news notifications in settings
    Component {
        id: newsPlaceholderPanel

        ColumnLayout {
            id: newsPanelLayout

            anchors.centerIn: parent
            width: 320
            spacing: 12

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width

                text: !root.newsEnabledViaRSS ? qsTr("Enable RSS to receive Status News notifications") :
                                                qsTr("Enable Status News notifications")
                font.weight: Font.Bold
                lineHeight: 1.2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width

                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
                text: !root.newsEnabledViaRSS ? qsTr("RSS is currently disabled via your Privacy & Security settings. Enable RSS to receive Status News notifications about upcoming features and important announcements.") :
                                                qsTr("This feature is currently turned off. Enable Status News notifications to receive notifications about upcoming features and important announcements")
                lineHeight: 1.2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            StatusButton {
                Layout.alignment: Qt.AlignHCenter

                text: !root.newsEnabledViaRSS ? qsTr("Enable RSS"):
                                                qsTr("Enable Status News notifications")
                font.pixelSize: Theme.additionalTextSize

                onClicked: {
                    if (!root.newsEnabledViaRSS) {
                        root.enableNewsViaRSSRequested()
                    } else {
                        root.enableNewsRequested()
                    }
                }
            }
        }
    }

    // This will be reworked on: https://github.com/status-im/status-app/issues/18905
    Component {
        id: emptyPlaceholderPanel

        StatusBaseText {
            // If the mode is unread only, it means the user has seen all notifications and is up to date
            // If the mode is all, it means there are no notifications to show
            text: root.readNotificationsStatus === ActivityCenterTypes.ActivityCenterReadType.Unread ?
                      qsTr("You're all caught up") :
                      qsTr("Your notifications will appear here")
            horizontalAlignment: Text.AlignHCenter
            color: Theme.palette.baseColor1
        }
    }
}
