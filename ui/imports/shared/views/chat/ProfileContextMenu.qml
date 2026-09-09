import QtQuick
import QtQuick.Controls

import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared
import shared.controls.chat
import shared.controls.chat.menuItems
import shared.status
import utils

StatusMenu {
    id: root

    property string compressedPubKey: ""
    property string displayName: ""
    property string userIcon: ""
    property int trustStatus: Constants.trustStatus.unknown
    property int contactType: Constants.contactType.nonContact
    property int onlineStatus: Constants.onlineStatus.unknown
    property int profileType: Constants.profileType.regular
    property string bridgeName: ""
    property bool hasLocalNickname: false
    property bool usesDefaultName: false
    property int chatType: Constants.chatType.unknown
    property bool isAdmin: false
    property var emojiHash: []
    property int colorId

    signal openProfileClicked
    signal createOneToOneChat
    signal reviewContactRequest
    signal sendContactRequest
    signal editNickname
    signal removeNickname
    signal unblockContact
    signal markAsTrusted
    signal removeTrustedMark
    signal markAsUntrusted
    signal removeTrustStatus
    signal removeContact
    signal blockContact
    signal removeFromGroup

    ProfileHeader {
        displayNameVisible: false
        displayNamePlusIconsVisible: true
        editButtonVisible: false
        displayName: StatusQUtils.Emoji.parse(root.displayName, StatusQUtils.Emoji.size.verySmall)
        usesDefaultName: root.usesDefaultName
        compressedPubKey: root.compressedPubKey
        emojiHash: root.emojiHash
        colorId: root.colorId
        icon: root.userIcon
        trustStatus: root.profileType === Constants.profileType.regular ? root.trustStatus : Constants.trustStatus.unknown
        isContact: root.profileType === Constants.profileType.regular ? root.contactType === Constants.contactType.contact : false
        isBlocked: root.profileType === Constants.profileType.blocked
        isCurrentUser: root.profileType === Constants.profileType.self
        isBridgedAccount: root.profileType === Constants.profileType.bridged
        bridgeName: root.bridgeName
        Binding on onlineStatus {
            value: root.onlineStatus
            when: root.profileType !== Constants.profileType.bridged
        }
    }

    StatusMenuSeparator {
        visible: root.profileType !== Constants.profileType.bridged
        topPadding: root.topPadding
        horizontalPadding: 0
    }

    ViewProfileMenuItem {
        id: viewProfileAction
        objectName: "viewProfile_StatusItem"
        enabled: root.profileType !== Constants.profileType.bridged
        onTriggered: {
            root.openProfileClicked()
            root.close()
        }
    }

    // Send Message
    SendMessageMenuItem {
        id: sendMessageMenuItem
        objectName: "sendMessage_StatusItem"
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.contact
        onTriggered: {
            root.createOneToOneChat()
            root.close()
        }
    }

    // Mark as trusted
    StatusAction {
        objectName: "markAsTrusted_StatusItem"
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.contact && root.trustStatus !== Constants.trustStatus.trusted
        text: qsTr("Mark as trusted")
        icon.name: "checkmark-circle"
        onTriggered: root.markAsTrusted()
    }

    // Review Contact Request
    StatusAction {
        text: qsTr("Review contact request")
        objectName: "reviewContactRequest_StatusItem"
        icon.name: "add-contact"
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.contactRequestReceived
        onTriggered: root.reviewContactRequest()
    }

    // Send Contact Request
    SendContactRequestMenuItem {
        id: sendContactRequestMenuItem
        objectName: "sendContactRequest_StatusItem"
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.nonContact
        onTriggered: root.sendContactRequest()
    }

    // Edit Nickname
    StatusAction {
        id: renameAction
        objectName: "rename_StatusItem"
        enabled: root.profileType === Constants.profileType.blocked || root.profileType === Constants.profileType.regular
        text: root.hasLocalNickname ? qsTr("Edit nickname") : qsTr("Add nickname")
        icon.name: "edit_pencil"
        onTriggered: root.editNickname()
    }

    StatusMenuSeparator {
        topPadding: root.topPadding
        visible: root.profileType !== Constants.profileType.bridged &&
                 (removeNicknameAction.enabled || unblockAction.enabled || markUntrustworthyMenuItem.enabled || removeUntrustworthyMarkMenuItem.enabled || removeContactAction.enabled || blockMenuItem.enabled)
        horizontalPadding: 0
    }

    // Remove Nickname
    StatusAction {
        id: removeNicknameAction
        text: qsTr("Remove nickname")
        icon.name: "delete"
        type: StatusAction.Type.Danger
        enabled: (root.profileType === Constants.profileType.blocked || root.profileType === Constants.profileType.regular) && root.hasLocalNickname
        onTriggered: root.removeNickname()
    }

    // Remove trusted mark
    StatusAction {
        objectName: "removeTrustedMark_StatusItem"
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.contact && root.trustStatus === Constants.trustStatus.trusted
        text: qsTr("Remove trusted mark")
        icon.name: "checkmark-circle"
        type: StatusAction.Type.Danger
        onTriggered: root.removeTrustedMark()
    }

    // Unblock User
    StatusAction {
        id: unblockAction
        objectName: "unblock_StatusItem"
        enabled: root.profileType === Constants.profileType.blocked
        text: qsTr("Unblock user")
        icon.name: "cancel"
        type: StatusAction.Type.Danger
        onTriggered: root.unblockContact()
    }

    StatusAction {
        text: qsTr("Remove from group")
        objectName: "removeFromGroup_StatusItem"
        icon.name: "remove-contact"
        type: StatusAction.Type.Danger
        enabled: root.isAdmin && root.profileType !== Constants.profileType.self && root.profileType !== Constants.profileType.bridged && root.chatType === Constants.chatType.privateGroupChat
        onTriggered: root.removeFromGroup()
    }

    // Mark as Untrusted
    StatusAction {
        id: markUntrustworthyMenuItem
        objectName: "markUntrustworthy_StatusItem"
        text: qsTr("Mark as untrusted")
        icon.name: "warning"
        type: StatusAction.Type.Danger
        enabled: root.profileType === Constants.profileType.regular && root.trustStatus !== Constants.trustStatus.untrustworthy
        onTriggered: root.markAsUntrusted()
    }

    // Remove Untrustworthy Mark
    StatusAction {
        id: removeUntrustworthyMarkMenuItem
        objectName: "removeUntrustworthy_StatusItem"
        text: qsTr("Remove untrusted mark")
        icon.name: "warning"
        type: StatusAction.Type.Danger
        enabled: root.profileType === Constants.profileType.regular && root.trustStatus === Constants.trustStatus.untrustworthy
        onTriggered: root.removeTrustStatus()
    }

    // Remove Contact
    StatusAction {
        id: removeContactAction
        text: qsTr("Remove contact")
        objectName: "removeContact_StatusItem"
        icon.name: "remove-contact"
        type: StatusAction.Type.Danger
        enabled: root.profileType === Constants.profileType.regular && root.contactType === Constants.contactType.contact
        onTriggered: root.removeContact()
    }

    // Block User
    StatusAction {
        id: blockMenuItem
        objectName: "blockUser_StatusItem"
        text: qsTr("Block user")
        icon.name: "cancel"
        type: StatusAction.Type.Danger
        enabled: root.profileType === Constants.profileType.regular
        onTriggered: root.blockContact()
    }
}
