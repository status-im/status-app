import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

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
    property string name
    property string communityDesc
    property color color
    property string channelName
    property string channelDesc

    // Blur view properties:
    property int membersCount
    property url image
    property var communityItemsModel
    property string chatDateTimeText
    property string listUsersText
    property var messagesModel

    headerContent: JoinCommunityHeaderPanel {
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
            amISectionAdmin: false
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.halfPadding
            layer.enabled: true
            layer.effect: blurEffect

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

    centerPanel: CommunityBannedMemberCenterPanel {
        anchors.fill: parent
        name: root.name
        chatDateTimeText: root.chatDateTimeText
        listUsersText: root.listUsersText
        messagesModel: root.messagesModel
    }

    showRightPanel: false

    Component {
        id: blurEffect

        MultiEffect {
            blurEnabled: true
            blur: 1.0
        }
    }
}
