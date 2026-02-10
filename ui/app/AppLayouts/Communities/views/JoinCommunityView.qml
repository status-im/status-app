import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Communities.panels
import AppLayouts.Chat.views

import StatusQ.Layout

import utils
import shared.popups

StatusSectionLayout {
    id: root

    // General properties:
    property bool amISectionAdmin: false
    property string name
    property string introMessage
    property string communityDesc
    property color color
    property string channelName
    property string channelDesc
    property bool joinCommunity: true // Otherwise it means join channel action
    property int accessType
    property int requestToJoinState: Constants.RequestToJoinState.None

    // Permission overlay view properties:
    property bool requirementsMet: true
    property bool requirementsCheckPending: false
    property bool isJoinRequestRejected: false
    property bool requiresRequest: false

    property var communityHoldingsModel
    property var viewOnlyHoldingsModel
    property var viewAndPostHoldingsModel
    property var moderateHoldingsModel
    property var assetsModel
    property var collectiblesModel

    // Blur view properties:
    property int membersCount
    property url image
    property var communityItemsModel
    property string chatDateTimeText
    property string listUsersText
    property var messagesModel

    signal infoButtonClicked
    signal requestToJoinClicked
    signal invitationPendingClicked

    QtObject {
        id: d

        readonly property int blurryRadius: 32
    }

    headerContent: JoinCommunityHeaderPanel {
        joinCommunity: root.joinCommunity
        color: root.color
        name: root.name
        channelName: root.channelName
        communityDesc: root.communityDesc
        channelDesc: root.channelDesc
    }

    // Blur background:
    leftPanel: ColumnLayout {
        anchors.fill: parent

        ColumnHeaderPanel {
            Layout.fillWidth: true
            name: root.name
            membersCount: root.membersCount
            image: root.image
            color: root.color
            amISectionAdmin: root.amISectionAdmin
            onInfoButtonClicked: if(root.amISectionAdmin) root.infoButtonClicked()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.halfPadding
            layer.enabled: root.joinCommunity
            layer.effect: fastBlur

            Repeater {
                model: root.communityItemsModel
                delegate: StatusChatListItem {
                    enabled: false
                    name: model.name
                    asset.color: root.color
                    selected: model.selected
                    type: StatusChatListItem.Type.CommunityChat
                    notificationsCount: model.notificationsCount
                    hasUnreadMessages: model.hasUnreadMessages
                }
            }
        }

        Item {
            // filler
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }

    // Blur background + Permissions base information content:
    centerPanel: JoinCommunityCenterPanel {
        id: joinCommunityCenterPanel

        anchors.fill: parent

        joinCommunity: root.joinCommunity // Otherwise it means join channel action

        name: root.name
        channelName: root.channelName

        requestToJoinState: root.requestToJoinState
        isJoinRequestRejected: root.isJoinRequestRejected
        requiresRequest: root.requiresRequest
        requirementsMet: root.requirementsMet
        requirementsCheckPending: root.requirementsCheckPending

        communityHoldingsModel: root.communityHoldingsModel
        viewOnlyHoldingsModel: root.viewOnlyHoldingsModel
        viewAndPostHoldingsModel: root.viewAndPostHoldingsModel
        moderateHoldingsModel: root.moderateHoldingsModel
        assetsModel: root.assetsModel
        collectiblesModel: root.collectiblesModel

        chatDateTimeText: root.chatDateTimeText
        listUsersText: root.listUsersText
        messagesModel: root.messagesModel

        onRequestToJoinClicked: root.requestToJoinClicked()
        onInvitationPendingClicked: root.invitationPendingClicked()
    }

    showRightPanel: false

    Component {
        id: fastBlur

        FastBlur {
            radius: d.blurryRadius
            transparentBorder: true
        }
    }
}
