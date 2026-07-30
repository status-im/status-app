import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import utils

ColumnLayout {
    id: root

    property string caption

    property alias components: delegate.components
    property alias highlighted: delegate.highlighted
    property int listItemHeight: 76

    required property string address
    property string name
    property string ens
    property string emoji
    property string walletColor

    StatusBaseText {
        text: root.caption
        font.pixelSize: Theme.additionalTextSize
    }
    RecipientViewDelegate {
        id: delegate
        objectName: "recipientDelegate"
        // StatusListItem sets Accessible.name but no role; roleless items are
        // dropped from the Android accessibility tree, hiding the account/address.
        Accessible.role: Accessible.StaticText

        Layout.fillWidth: true
        Layout.preferredHeight: root.listItemHeight

        address: root.address
        name: root.name
        ens: root.ens
        emoji: root.emoji
        walletColor: root.walletColor

        elideAddressInTitle: true
        useAddressAsLetterIdenticon: !root.name && !root.ens

        sensor.enabled: false

        statusListItemSubTitle.font.pixelSize: Theme.additionalTextSize
        statusListItemTitle.customColor: Theme.palette.directColor1
        statusListItemTitle.font.pixelSize: Theme.additionalTextSize
        statusListItemTitle.elide: Text.ElideMiddle
        statusListItemTitle.textFormat: Text.PlainText
        statusListItemSubTitle.textFormat: Text.PlainText
        border.width: 1
        border.color: Theme.palette.baseColor2

        asset.bgWidth: 40
        asset.bgHeight: 40
        rightPadding: Theme.padding
    }
}
