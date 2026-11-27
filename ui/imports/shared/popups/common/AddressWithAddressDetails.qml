import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils
import shared.controls

import AppLayouts.Wallet

Column {
    id: root

    property string addressText: ""
    property string addressColor: Theme.palette.directColor1
    property var addressDetailsItem
    property bool addressResolved: true
    property bool displayDetails: true
    property bool displayCopyButton: true
    property bool alreadyCreatedAccountIsAnError: true
    property bool revealNeedsPassword: false

    spacing: Theme.halfPadding

    StatusBaseText {
        text: root.addressText
    }

    StatusInput {
        width: parent.width
        text: WalletUtils.ownAddressToDisplay(root.addressDetailsItem.address, root.revealNeedsPassword)
        input.edit.enabled: false
        input.edit.color: root.addressColor
        input.background.color: "transparent"
        input.background.border.color: Theme.palette.baseColor2
        input.rightComponent: CopyButton {
            visible: root.displayCopyButton
            textToCopy: root.addressDetailsItem.address
            revealNeedsPassword: root.revealNeedsPassword
        }
    }

    AddressDetails {
        width: parent.width
        visible: root.displayDetails
        addressDetailsItem: root.addressDetailsItem
        defaultMessage: ""
        defaultMessageCondition: !root.addressResolved
        alreadyCreatedAccountIsAnError: root.alreadyCreatedAccountIsAnError
    }
}
