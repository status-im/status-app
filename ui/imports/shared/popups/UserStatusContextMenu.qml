import StatusQ.Popups

import shared.controls.chat
import shared.controls.chat.menuItems
import shared.panels
import utils

StatusMenu {
    id: root

    property alias compressedPubKey: header.compressedPubKey
    property alias emojiHash: header.emojiHash
    property alias name: header.displayName
    property alias headerIcon: header.icon
    property alias colorId: header.colorId
    property alias usesDefaultName: header.usesDefaultName

    // Constants.currentUserStatus
    property int currentUserStatus

    signal viewProfileRequested
    signal shareProfileRequested
    signal copyLinkRequested
    signal setCurrentUserStatusRequested(int status)

    ProfileHeader {
        id: header

        objectName: 'onlineIdentifierProfileHeader'

        width: parent.width
    }

    StatusMenuSeparator {}

    ViewProfileMenuItem {
        objectName: "userStatusViewMyProfileAction"
        onTriggered: {
            root.viewProfileRequested()
            root.close()
        }
    }

    StatusAction {
        objectName: "userStatusShareProfileAction"
        text: qsTr("Share Profile")
        icon.name: "qr"
        onTriggered: {
            root.shareProfileRequested()
            root.close()
        }
    }

    StatusAction {
        objectName: "userStatusCopyLinkAction"
        text: qsTr("Copy link to profile")
        icon.name: "copy"
        onTriggered: {
            root.copyLinkRequested()
            root.close()
        }
    }

    StatusMenuSeparator {}

    StatusAction {
        objectName: "userStatusMenuAlwaysOnlineAction"
        text: qsTr("Always online")
        assetSettings.name: "statuses/online"
        assetSettings.width: 12
        assetSettings.height: 12
        assetSettings.color: "transparent"
        fontSettings.bold: root.currentUserStatus === Constants.currentUserStatus.alwaysOnline
        onTriggered: {
            root.setCurrentUserStatusRequested(Constants.currentUserStatus.alwaysOnline)
            root.close()
        }
    }

    StatusAction {
        objectName: "userStatusMenuInactiveAction"
        text: qsTr("Inactive")
        assetSettings.name: "statuses/inactive"
        assetSettings.width: 12
        assetSettings.height: 12
        assetSettings.color: "transparent"
        fontSettings.bold: root.currentUserStatus === Constants.currentUserStatus.inactive
        onTriggered: {
            root.setCurrentUserStatusRequested(Constants.currentUserStatus.inactive)
            root.close()
        }
    }

    StatusAction {
        objectName: "userStatusMenuAutomaticAction"
        text: qsTr("Set status automatically")
        assetSettings.name: "statuses/automatic"
        assetSettings.color: "transparent"
        fontSettings.bold: root.currentUserStatus === Constants.currentUserStatus.automatic
        onTriggered: {
            root.setCurrentUserStatusRequested(Constants.currentUserStatus.automatic)
            root.close()
        }
    }
}
