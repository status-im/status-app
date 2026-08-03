import QtQuick

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

    readonly property string displayAddress: WalletUtils.preferredAddress(root.selectedAccount)

    signal copyToClipboard(string address)

    function openMenu(delegate) {
        const x = delegate.width - 40
        const y = delegate.height / 2 + 20
        root.popup(delegate, x, y)
    }

    BlockchainExplorersMenu {
        id: blockchainExplorersMenu
        flatNetworks: root.flatNetworks
        onNetworkClicked: {
            let link = Utils.getUrlForAddressOnNetwork(shortname, isTestnet, root.selectedAccount.address ?? "");
            Global.requestOpenLink(link);
        }
    }

    StatusSuccessAction {
        id: copyAddressAction
        successText:  qsTr("Address copied")
        text: qsTr("Copy address")
        icon.name: "copy"
        onTriggered: root.copyToClipboard(root.displayAddress)
    }
    StatusAction {
        id: showQrAction
        text: qsTr("Show address QR")
        icon.name: "qr"
        onTriggered: Global.openShowQRPopup({
                                                showSingleAccount: true,
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
