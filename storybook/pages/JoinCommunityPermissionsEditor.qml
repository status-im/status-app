import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models

import utils

ColumnLayout {
    id: root

    property bool isOnlyChannelPanelEditor: false
    property string channelName: "vip"
    property bool joinCommunity: true // Otherwise, enter channel
    property bool requirementsMet: true
    property bool requirementsCheckPending: false
    property bool isInvitationPending: false
    property bool isJoinRequestRejected: false
    property bool requiresRequest: false
    property var communityHoldingsModel: PermissionsModel.shortPermissionsModel
    property var viewOnlyHoldingsModel: PermissionsModel.shortPermissionsModel
    property var viewAndPostHoldingsModel: PermissionsModel.shortPermissionsModel
    property var moderateHoldingsModel: PermissionsModel.shortPermissionsModel

    spacing: 16

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor
        Label {
            Layout.fillWidth: true
            text: "View type:"
        }

        RadioButton {
            checked: true
            text: "Join community"
            onCheckedChanged: if(checked) d.joinCommunity =  true
        }

        RadioButton {
            text: "Enter channel"
            onCheckedChanged: if(checked) d.joinCommunity = false
        }
    }

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor
        Label {
            Layout.fillWidth: true
            text: "Requirements met:"
        }

        CheckBox {
            checked: root.requirementsMet
            onCheckedChanged: root.requirementsMet = checked
        }
    }

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor
        Label {
            Layout.fillWidth: true
            text: "Requirements check pending:"
        }

        CheckBox {
            checked: root.requirementsCheckPending
            onCheckedChanged: root.requirementsCheckPending = checked
        }
    }

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor
        Label {
            Layout.fillWidth: true
            text: "Request pending:"
        }

        CheckBox {
            checked: root.isInvitationPending
            onCheckedChanged: root.isInvitationPending = checked
        }
    }

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor
        Label {
            Layout.fillWidth: true
            text: "Request rejected:"
        }

        CheckBox {
            checked: root.isJoinRequestRejected
            onCheckedChanged: root.isJoinRequestRejected = checked
        }
    }

    ColumnLayout {
        visible: !isOnlyChannelPanelEditor && root.joinCommunity
        Label {
            Layout.fillWidth: true
            text: "Requires request:"
        }

        CheckBox {
            checked: root.requiresRequest
            onCheckedChanged: root.requiresRequest = checked
        }
    }

    ColumnLayout {
        visible: root.joinCommunity
        Label {
            Layout.fillWidth: true
            text: "Holdings model type:"
        }

        RadioButton {
            checked: true
            text: "Short model"
            onCheckedChanged: if(checked) root.communityHoldingsModel = PermissionsModel.shortPermissionsModel
        }

        RadioButton {
            text: "Long model"
            onCheckedChanged: if(checked) root.communityHoldingsModel = PermissionsModel.longPermissionsModel
        }

        RadioButton {
            text: "Private met model"
            onCheckedChanged: if(checked) root.communityHoldingsModel = PermissionsModel.privatePermissionsModel
        }

        RadioButton {
            text: "Private not met model"
            onCheckedChanged: if(checked) root.communityHoldingsModel = PermissionsModel.privatePermissionsNotMetModel
        }
    }

    ColumnLayout {
        visible: !root.joinCommunity

        Label {
            Layout.fillWidth: true
            text: "Channel name"
        }

        TextField {
            background: Rectangle { border.color: 'lightgrey' }
            Layout.preferredWidth: 200
            text: root.channelName
            onTextChanged: root.channelName = text
        }
    }

    ColumnLayout {
        visible: !root.joinCommunity

        Label {
            Layout.fillWidth: true
            text: "Only view holdings model type:"
        }

        RadioButton {
            checked: true
            text: "Short model"
            onCheckedChanged: if(checked) root.viewOnlyHoldingsModel = PermissionsModel.shortPermissionsModel
        }

        RadioButton {
            text: "Long model"
            onCheckedChanged: if(checked) root.viewOnlyHoldingsModel = PermissionsModel.longPermissionsModel
        }

        RadioButton {
            text: "None"
            onCheckedChanged: if(checked) root.viewOnlyHoldingsModel = undefined
        }
    }

    ColumnLayout {
        visible: !root.joinCommunity

        Label {
            Layout.fillWidth: true
            text: "View and post holdings model type:"
        }

        RadioButton {
            checked: true
            text: "Short model"
            onCheckedChanged: if(checked) root.viewAndPostHoldingsModel = PermissionsModel.shortPermissionsModel
        }

        RadioButton {
            text: "Long model"
            onCheckedChanged: if(checked) root.viewAndPostHoldingsModel = PermissionsModel.longPermissionsModel
        }

        RadioButton {
            text: "None"
            onCheckedChanged: if(checked) root.viewAndPostHoldingsModel = undefined
        }
    }

    ColumnLayout {
        visible: !root.joinCommunity

        Label {
            Layout.fillWidth: true
            text: "Moderate holdings model type:"
        }

        RadioButton {
            checked: true
            text: "Short model"
            onCheckedChanged: if(checked) root.moderateHoldingsModel = PermissionsModel.shortPermissionsModel
        }

        RadioButton {
            text: "Long model"
            onCheckedChanged: if(checked) root.moderateHoldingsModel = PermissionsModel.longPermissionsModel
        }

        RadioButton {
            text: "None"
            onCheckedChanged: if(checked) root.moderateHoldingsModel = undefined
        }
    }
}
