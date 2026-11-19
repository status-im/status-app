import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils


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
    signal menuOpened()
    signal shareOwnProfileRequested
    signal settingsRequested
    signal setCurrentUserStatusRequested(int status)
    signal quitRequested

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
        if (root.loading)
            return
        if (d.menu) {
            d.menu.close()
            return
        }
        d.menu = userStatusContextMenuComponent.createObject(root)
        d.menu.open()
        root.menuOpened()
    }

    QtObject {
        id: d
        property var menu: null
    }

    SQUtils.DeferredComponent {
        id: userStatusContextMenuComponent

        source: Qt.resolvedUrl("../popups/UserStatusContextMenu.qml")
        properties: ({
            objectName: "userStatusContextMenu",
            directParent: root,
            relativeX: Qt.binding(() => root.x + root.width + 8),
            compressedPubKey: Qt.binding(() => root.compressedPubKey),
            emojiHash: Qt.binding(() => root.getEmojiHashFn(root.pubKey)),
            colorId: Qt.binding(() => root.colorId),
            name: Qt.binding(() => root.name),
            headerIcon: Qt.binding(() => root.iconSource),
            usesDefaultName: Qt.binding(() => root.usesDefaultName),
            bio: Qt.binding(() => root.bio),
            currentUserStatus: Qt.binding(() => root.currentUserStatus)
        })

        onCreated: menu => {
            menu.relativeY = Qt.binding(() => root.y - menu.height + root.height)
            menu.viewProfileRequested.connect(() => root.viewProfileRequested(root.pubKey))
            menu.shareOwnProfileRequested.connect(() => root.shareOwnProfileRequested())
            menu.settingsRequested.connect(() => root.settingsRequested())
            menu.copyLinkRequested.connect(() => ClipboardUtils.setText(root.getLinkToProfileFn(root.pubKey)))
            menu.setCurrentUserStatusRequested.connect(status => root.setCurrentUserStatusRequested(status))
            menu.quitRequested.connect(() => root.quitRequested())
            menu.closed.connect(() => {
                d.menu = null
                menu.destroy()
            })
        }
    }
}
