import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Core.Theme

import shared.popups

import utils

StatusIconTabButton {
    id: root

    required property string name
    required property string usesDefaultName
    required property string pubKey
    required property string compressedPubKey
    required property string iconSource
    required property int colorId
    required property int currentUserStatus
    property string bio

    property bool loading: false
    property var getLinkToProfileFn: function(pubKey) { console.error("IMPLEMENT ME"); return "" }
    property var getEmojiHashFn: function(pubKey) { console.error("IMPLEMENT ME"); return "" }

    signal viewProfileRequested(string pubKey)
    signal shareOwnProfileRequested
    signal setCurrentUserStatusRequested(int status)

    name: root.name
    enabled: !root.loading
    icon.name: root.loading ? "loading" : ""
    icon.source: root.loading ? "" : root.iconSource
    implicitWidth: 32
    implicitHeight: 32
    identicon.asset.width: width
    identicon.asset.height: height
    identicon.asset.useAcronymForLetterIdenticon: true

    identicon.asset.name: {
        if (root.loading) {
            return "loading"
        }
        if (identicon.asset.isImage) {
            return icon.source
        }
        if (root.usesDefaultName) {
            return "contact"
        }
        return icon.name
    }
    identicon.asset.bgWidth: root.usesDefaultName ? width : 0
    identicon.asset.bgHeight: root.usesDefaultName ? height : 0
    identicon.asset.color: root.usesDefaultName ? Theme.palette.indirectColor2 : Utils.colorForPubkey(Theme.palette, root.pubKey)
    identicon.asset.isLetterIdenticon: root.usesDefaultName ? false : icon.name !== "" && !identicon.asset.isImage
    identicon.asset.bgColor: root.usesDefaultName ? Utils.colorForPubkey(Theme.palette, root.pubKey) : "transparent"

    identicon.badge.visible: !root.loading
    identicon.badge.border.width: 2
    identicon.badge.border.color: Theme.palette.statusAppNavBar.backgroundColor
    identicon.badge.height: 12
    identicon.badge.width: 12
    identicon.badge.color: {
        switch(root.currentUserStatus) {
        case Constants.currentUserStatus.automatic:
        case Constants.currentUserStatus.alwaysOnline:
            return Theme.palette.successColor1
        default:
            return Theme.palette.baseColor1
        }
    }

    onClicked: {
        if (!root.loading)
            userStatusContextMenu.opened ? userStatusContextMenu.close() : userStatusContextMenu.open()
    }

    UserStatusContextMenu {
        id: userStatusContextMenu
        objectName: "userStatusContextMenu"

        directParent: root

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        relativeY: root.y - userStatusContextMenu.height + root.height
        relativeX: root.x + root.width + 8

        compressedPubKey: root.compressedPubKey
        emojiHash: root.getEmojiHashFn(root.pubKey)
        colorId: root.colorId
        name: root.name
        headerIcon: root.iconSource
        usesDefaultName: root.usesDefaultName
        bio: root.bio

        currentUserStatus: root.currentUserStatus

        onViewProfileRequested: root.viewProfileRequested(root.pubKey)
        onShareOwnProfileRequested: root.shareOwnProfileRequested()
        onCopyLinkRequested: ClipboardUtils.setText(root.getLinkToProfileFn(root.pubKey))
        onSetCurrentUserStatusRequested: (status) => root.setCurrentUserStatusRequested(status)
    }
}
