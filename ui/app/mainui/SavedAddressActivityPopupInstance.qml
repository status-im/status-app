import QtQuick

import AppLayouts.Wallet.popups as WalletPopups

import utils

WalletPopups.SavedAddressActivityPopup {
    id: root

    required property var params

    onSendToAddressRequested: address => Global.sendToRecipientRequested(address)

    Component.onCompleted: root.initWithParams(root.params)
}
