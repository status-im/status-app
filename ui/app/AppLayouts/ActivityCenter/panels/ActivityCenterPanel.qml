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

// This component provides criteria for displaying notifications (category, read/unread) and renders provided list of modifications.
// It's consumer's responsibility to adjust model data to the criteria exposed by the component.
//
// Additionally consumer is obliged to provide other hints like (hasAdmin, hasMentions, hasReplies, etc.) which cannot be inferred from
// provided model because dynamic `fetch more` approach is used.
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


    // Here is an example of the complete set of roles the `notificationsModel` can contain:
    //
    // ** Card states related:
    //    unread: false,
    //    selected: false,
    //
    // ** Avatar related:
    //    avatarSource: "https://i.pravatar.cc/128?img=8",
    //    badgeIconName: "action-mention",
    //    isCircularAvatar: true,
    //
    // ** Header row related
    //    title: "Notification 2",
    //    chatKey: "zQ3saskd11lfkjs1dkf5Rj9",
    //    isContact: true,
    //    trustIndicator: 0,
    //
    // ** Context row related
    //    primaryText: "Communities",
    //    iconName: "communities",
    //    secondaryText: "Channel 12",
    //    separatorIconName: "arrow-next",
    //
    // ** Action text
    //    actionText: "Action Text",
    //
    // ** Content block related
    //    preImageSource: "https://picsum.photos/320/240?6",
    //    preImageRadius: 8,
    //    content: "Some notification description that can be long and long and long",
    //    attachments: [
    //                    "https://picsum.photos/320/240?1",
    //                    "https://picsum.photos/320/240?2",
    //                    "https://picsum.photos/320/240?9"
    //                    ],
    //
    // ** Timestamp related
    //    timestamp: 1765799225000
    //
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
            Layout.fillHeight: true
            Layout.topMargin: 2

            visible: !d.emptyNotificationsList && !d.isNewsPlaceholderActive
            enabled: !d.optionsMenuVisible
            verticalScrollBar.implicitWidth: Theme.halfPadding

            spacing: 4
            implicitHeight: contentHeight
            model: root.notificationsModel
            delegate: NotificationCard {
                enabled: !d.optionsMenuVisible

                anchors.left: listView.contentItem.left
                anchors.right: listView.contentItem.right
                anchors.margins: Theme.halfPadding

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

        // Placeholder for the status news when their settings are disabled
        // OR Placeholder for the status news when they are all seen or there are no notifications
        Loader {
            id: placeholderLoader

            Layout.topMargin: 2
            Layout.bottomMargin: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: d.isNewsPlaceholderActive || d.emptyNotificationsList

            sourceComponent: d.isNewsPlaceholderActive ? newsPlaceholderPanel : emptyPlaceholderPanel
        }

        // Filler
        Item {
            Layout.fillHeight: placeholderLoader.active || d.emptyNotificationsList
        }
    }

    // If !root.newsEnabledViaRSS it means the panel is for enabling RSS notification
    // Otherwise, it means it is for enabling status news notifications in settings
    Component {
        id: newsPlaceholderPanel

        Item {
            anchors.fill: parent

            ColumnLayout {
                id: newsPanelLayout

                anchors.centerIn: parent
                width: parent.width - 2 * Theme.bigPadding
                spacing: Theme.halfPadding

                Image {
                    Layout.alignment: Qt.AlignHCenter

                    source: (Theme.style === Theme.Light) ? Assets.png("activity_center/NewsDisabled-Light") :
                                                            Assets.png("activity_center/NewsDisabled-Dark")
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    cache: false
                }

                StatusBaseText {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    text: !root.newsEnabledViaRSS ? qsTr("Status News RSS is off") :
                                                    qsTr("Status News notifications are off")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                }

                StatusBaseText {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    text: !root.newsEnabledViaRSS ? qsTr("Turn it on to get updates about new features and announcements. You can also enable this anytime in Privacy & Security settings.") :
                                                    qsTr("Turn them on to get updates about new features and announcements. You can also enable this anytime in Notifications and Sound settings.")

                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Light
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width

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
    }

    // This is used whenever the list of notifications is empty
    Component {
        id: emptyPlaceholderPanel

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.bigPadding
                spacing: Theme.halfPadding

                Image {
                    Layout.alignment: Qt.AlignHCenter

                    source: (Theme.style === Theme.Light) ? Assets.png("activity_center/EmptyNotifications-Light") :
                                                            Assets.png("activity_center/EmptyNotifications-Dark")
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    cache: false
                }

                StatusBaseText {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No notifications right now.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                }

                StatusBaseText {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Check back later for updates.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Light
                }
            }
        }
    }
}
