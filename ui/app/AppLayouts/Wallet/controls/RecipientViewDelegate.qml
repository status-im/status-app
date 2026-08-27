import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import StatusQ.Core.Utils as StatusQUtils

import utils

StatusListItem {
    id: root

    property bool useAddressAsLetterIdenticon: false
    property bool elideAddressInTitle: false

    property string name
    property string address
    property string emoji
    property string walletColor
    property string walletColorId
    property string ens

    signal cleared()

    QtObject {
        id: d

        function getSubtitle(elideAddress) {
            if (!!root.ens) {
                return root.ens
            }
            if (!!root.address) {
                if (root.sensor.containsMouse) {
                    return root.address
                }
                // NOTE elide text is used instead of elide wallet address because 0x00D7 shows incorrectly in identicon
                return elideAddress ? StatusQUtils.Utils.elideText(root.address, 6, 4) : root.address
            }
            return ""
        }
    }

    objectName: root.name

    implicitHeight: 64
    title: !!root.name ? root.name : d.getSubtitle(root.elideAddressInTitle)
    rightPadding: Theme.halfPadding
    subTitle: !!root.name ? d.getSubtitle(true) : ""

    color: sensor.containsMouse || highlighted ? Theme.palette.baseColor2 : "transparent"

    statusListItemSubTitle.wrapMode: Text.NoWrap
    statusListItemSubTitle.font.family: Fonts.codeFont.family
    statusListItemSubTitle.font.pixelSize: Theme.fontSize(14)
    statusListItemSubTitle.elide: Text.ElideRight
    statusListItemSubTitle.customColor: sensor.containsMouse ? Theme.palette.directColor1 : Theme.palette.baseColor1
    statusListItemTitle.elide: Text.ElideRight
    statusListItemTitle.font.family: Fonts.monoFont.family
    statusListItemIcon.name: useAddressAsLetterIdenticon ? root.address : title

    asset.emoji: root.emoji
    asset.color: {
        if (root.useAddressAsLetterIdenticon || (!root.name && !root.ens)) {
            return Theme.palette.directColor1
        }
        if (!!root.walletColor)
            return root.walletColor
        if (!!root.walletColorId)
            return Utils.getColorForId(Theme.palette, root.walletColorId)
        return ""
    }
    asset.name: !!root.emoji ? "filled-account" : title
    asset.letterSize: 14
    asset.charactersLen: 2
    asset.isLetterIdenticon: true
    asset.useAcronymForLetterIdenticon: statusListItemIcon.name !== root.address
    asset.letterIdenticonBgWithAlpha: !root.emoji
    asset.bgColor: Theme.palette.indirectColor1
    asset.width: 40
    asset.height: 40
}
