import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.popups as WalletPopups

import QtModelsToolkit

WalletPopups.ReceiveModal {
    id: root

    // true when a single account or a saved address is shown, without the account switcher
    property bool fixedAccount
    property var fixedSelectedAccount
    property var allAccounts
    property var receiverAccounts
    property string selectedReceiverAddress

    signal receiverAccountSelected(string address)

    ModelEntry {
        id: selectedReceiverAccount
        key: "address"
        sourceModel: root.receiverAccounts
        value: root.selectedReceiverAddress
    }

    accounts: root.fixedAccount ? null : root.allAccounts

    selectedAccount: {
        if (root.fixedAccount)
            return root.fixedSelectedAccount
        return selectedReceiverAccount.item ?? SQUtils.ModelUtils.get(root.receiverAccounts, 0)
    }

    onUpdateSelectedAddress: address => {
        if (!root.fixedAccount)
            root.receiverAccountSelected(address)
    }
}
