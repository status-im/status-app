import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.ActivityCenter.helpers

import utils

SQUtils.QObject {
    id: root

    required property ActivityNotification notification

    // Defaults (override in specific adaptors)
    // Avatar related
    property string avatarSource: ""
    property string badgeIconName: ""
    property bool isCircularAvatar: false
    property bool isAvatarClickable: false
    property string avatarId: ""
    property color avatarLetterColor: Theme.palette.miscColor5
    property string avatarLetterText: ""
    property bool isAvatarLetterAcronym: true
    property int avatarMaxTextLen: 2

    // Header row related
    property string title: ""
    property string chatKey: ""
    property bool isContact: false
    property int trustIndicator: Constants.trustStatus.unknown
    property bool isBlocked: false

    // Context row related
    readonly property NotificationAdaptorContext context: NotificationAdaptorContext {
        chatType: notification?.chatType ?? Constants.chatType.unknown
    }
    readonly property string primaryText: context.primaryText
    readonly property url    contextAvatar: context.contextAvatar
    readonly property string iconName: context.iconName
    readonly property string secondaryText: context.secondaryText ?? ""
    readonly property string separatorIconName: context.separatorIconName

    // Action text
    property string actionText: ""

    // Content block related
    property string preImageSource: ""
    property int preImageRadius: Theme.radius
    property string content: ""
    property var attachments: []
    property bool showQuickActions: false
    property string actionId: ""

    // Others (navigation related data)
    property string subsectionItemId: ""
    property bool redirectToSection: false
    property bool redirectToDetails: false
    property bool redirectToCommunitySettingsSubsection: false
    property int communitySettingsSubsection: -1
    property int communitySettingsSubsectionItem: -1
    property bool redirectToLink: false
    property bool redirectToWallet: false
}
