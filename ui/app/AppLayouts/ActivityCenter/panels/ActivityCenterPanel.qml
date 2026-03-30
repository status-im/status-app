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

    // Notifications Interactions
    signal closeRequested()
    signal markAllAsReadRequested()
    signal hideShowReadNotificationsRequested()
    signal setActiveGroupRequested(int group)
    signal fetchMoreNotificationsRequested()
    signal enableNewsViaRSSRequested()
    signal enableNewsRequested()

    // Card interactions
    signal avatarClicked(string avatarId)
    signal redirectToDetails(string sectionId, string subsectionId, string itemId)
    signal redirectToSection(string sectionId)
    signal redirectToPopup(var notification)
    signal redirectToWallet(string address, string txHash)

    // Emitted when quick actions are shown and user iteracts with the corresponding buttons
    signal declineRequested(string avatarId, string actionId)
    signal acceptRequested(string avatarId, string actionId)

    TapHandler {
        acceptedButtons: Qt.RightButton
    }

    QtObject {
        id: d

        readonly property bool emptyNotificationsList: listView.count === 0
        readonly property bool newsDisabledBySettings: !root.newsEnabledViaRSS || root.newsSettingsStatus === Constants.settingsSection.notifications.turnOffValue
        readonly property bool isNewsPlaceholderActive: root.activeGroup === ActivityCenterTypes.ActivityCenterGroup.NewsMessage && d.newsDisabledBySettings

        readonly property var fetchMoreNotifications: Backpressure.oneInTimeQueued(root, 100, function() {
            if (listView.contentY >= listView.contentHeight - listView.height - 1) {
                root.fetchMoreNotificationsRequested()
            }
        })
    }

    objectName: "activityCenterPanel"
    background: Rectangle {
        color: parent.backgroundColor
        radius: Theme.radius
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
                id: markAllReadBtn
                objectName: "markAllReadButton"
                icon.name: "double-checkmark"
                onClicked: root.markAllAsReadRequested()
            }

            StatusFlatRoundButton {
                id: hideReadNotificationsBtn
                objectName: "hideShowButton"
                icon.name: root.hideReadNotifications ? "show" : "hide"
                onClicked: root.hideShowReadNotificationsRequested()
            }

            StatusFlatRoundButton {
                objectName: "closeButton"
                icon.name: "close"
                onClicked: root.closeRequested()
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
            objectName: "listView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 2

            visible: !d.emptyNotificationsList && !d.isNewsPlaceholderActive
            verticalScrollBar.implicitWidth: Math.max(Theme.halfPadding, 8)

            spacing: 4
            implicitHeight: contentHeight
            model: root.notificationsModel
            delegate: NotificationCard {
                anchors.left: listView.contentItem.left
                anchors.right: listView.contentItem.right
                anchors.margins: Math.max(Theme.halfPadding, 8)

                // Card states related
                unread: model.unread

                // Avatar related
                avatarSource: model.avatarSource
                badgeIconName: model.badgeIconName
                isCircularAvatar: model.isCircularAvatar
                isAvatarClickable: model.isAvatarClickable
                isBadgeClickable: model.isAvatarClickable
                avatarLetterColor: model.avatarLetterColor
                avatarLetterText: model.avatarLetterText
                isAvatarLetterAcronym: model.isAvatarLetterAcronym
                avatarMaxTextLen: model.avatarMaxTextLen

                // Header row related
                title: model.title
                chatKey: model.chatKey
                isContact: model.isContact
                trustIndicator: model.trustIndicator
                isBlocked: model.isBlocked

                // Context row related
                primaryText: model.primaryText
                contextAvatar: model.contextAvatar
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
                avatarId: model.avatarId ?? ""
                actionId: model.showQuickActions ? (model.actionId ?? "") : ""

                // Timestamp related
                timestamp: model.timestamp

                // Interactions
                onClicked: {
                    if(model.redirectToDetails)
                        return root.redirectToDetails(model.sectionId, model.subsectionId, model.subsectionItemId)

                    if (model.redirectToSection)
                        return root.redirectToSection(model.sectionId)

                    if (model.redirectToLink)
                        return root.redirectToPopup(model)

                    if(model.redirectToWallet)
                        return root.redirectToWallet(model.tokenData.walletAddress, model.tokenData.txHash)

                    // If no specific redirection but avatarId has some value, redirection will be to
                    // avatar information
                    if(model.avatarId)
                        return root.avatarClicked(model.avatarId)

                    // No actions when clicked
                }
                onAvatarClicked: root.avatarClicked(model.avatarId)
                onAcceptRequested: root.acceptRequested(model.avatarId ?? "", model.actionId ?? "")
                onDeclineRequested: root.declineRequested(model.avatarId ?? "", model.actionId ?? "")
            }

            onContentYChanged: d.fetchMoreNotifications()
        }

        // Placeholder for the status news when their settings are disabled
        // OR Placeholder for the status news when they are all seen or there are no notifications
        Loader {
            id: placeholderLoader
            objectName: "placeholderLoader"

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
