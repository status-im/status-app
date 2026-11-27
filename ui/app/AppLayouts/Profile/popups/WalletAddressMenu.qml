import QtQuick

import StatusQ
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared.popups
import utils

import AppLayouts.Wallet
import AppLayouts.Wallet.popups

////////////////////////////////////////////////////////////////////////////////
// NOTE:
//
// The address should be marked as shown (calling `mainModule.addressWasShown(address)`) if the user interacts with any
// of the current actions in the menu.
//
// That call is not added now, just because the only place where this menu is used is in the account view and the address
// will be already marked as shown when the user opens the account view.
//
// This note here is just to remember that if this menu is used in other places, the address should be marked as shown.
////////////////////////////////////////////////////////////////////////////////

StatusMenu {
    id: root

    property var selectedAccount: ({
                                       address: "",
                                       mixedcaseAddress: "",
                                       name: "",
                                       emoji: "",
                                       colorId: "",
                                   })
    property var flatNetworks
    property bool revealNeedsPassword: false

    readonly property string displayAddress: WalletUtils.preferredAddress(root.selectedAccount)

    function openMenu(delegate) {
        const x = delegate.width - 40
        const y = delegate.height / 2 + 20
        root.popup(delegate, x, y)
    }

    BlockchainExplorersMenu {
        id: blockchainExplorersMenu
        flatNetworks: root.flatNetworks
        onNetworkClicked: {
            const link = Utils.getUrlForAddressOnNetwork(shortname, isTestnet, root.selectedAccount.address ?? "")
            if (root.revealNeedsPassword)
                Global.openOwnAddressLinkRequested(link)
            else
                Global.requestOpenLink(link)
        }
    }

    StatusSuccessAction {
        id: copyAddressAction
        objectName: "walletAddressMenuCopyAction"
        showSuccess: !root.revealNeedsPassword
        successText:  qsTr("Address copied")
        text: qsTr("Copy address")
        icon.name: "copy"
        onTriggered: {
            if (!root.revealNeedsPassword) {
                ClipboardUtils.setText(root.displayAddress)
                return
            }
            // Nothing is copied before the password is set, so no "copied" state either
            Global.copyOwnAddressRequested(root.displayAddress)
            root.close()
        }
    }
    StatusAction {
        id: showQrAction
        objectName: "walletAddressMenuQrAction"
        text: qsTr("Show address QR")
        icon.name: "qr"
        onTriggered: Global.openShowQRPopup({
                                                showSingleAccount: true,
                                                revealNeedsPassword: root.revealNeedsPassword,
                                                switchingAccounsEnabled: false,
                                                hasFloatingButtons: false,
                                                name: root.selectedAccount.name?? "",
                                                address: root.selectedAccount.address?? "",
                                                mixedcaseAddress: root.displayAddress,
                                                emoji: root.selectedAccount.emoji?? "",
                                                colorId: root.selectedAccount.colorId?? ""
                                            })
    }
}
