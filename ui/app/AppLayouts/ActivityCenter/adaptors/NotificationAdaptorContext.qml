import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

SQUtils.QObject {
    id: root

    required property int chatType

    /*!
        Icon representing the notification context (community / group / channel).
        When empty, no context icon shown.
    */
    property string contextImageSource: ""

    /*!
        Avatar representing the notification context (community / group / channel).
        When empty, no context avatar shown.
    */
    property string contextAvatar: ""

    /*!
        Primary contextual name ("where" it happened).
        - community: community name
        - group: group name
        - no context: empty
    */
    property string contextPrimaryName: ""

    /*!
        Secondary contextual name (sub-context when applicable).
        - community: channel name (without '#')
        - group/nno context: empty
    */
    property string contextSecondaryName: ""

    // -------------------------
    // Derived context kind
    // -------------------------

    readonly property bool isCommunity: root.chatType === Constants.chatType.unknown /*Meaning directly a community*/ ||
                                        root.chatType === Constants.chatType.communityChat /*Meaning a community channel*/
    readonly property bool isGroup: root.chatType === Constants.chatType.privateGroupChat
    readonly property bool noContext: !isCommunity && !isGroup

    // -------------------------
    // Context row related
    // -------------------------

    readonly property string primaryText: {
        if (root.isCommunity || root.isGroup)
            return contextPrimaryName
        return ""
    }
    readonly property string iconName: root.isCommunity ? "communities" : ""
    readonly property string secondaryText: {
        if (root.isCommunity && !!root.contextSecondaryName)
            return "#" + root.contextSecondaryName
        return ""
    }
    readonly property string separatorIconName: root.isCommunity && secondaryText ? "arrow-next" : ""
}
