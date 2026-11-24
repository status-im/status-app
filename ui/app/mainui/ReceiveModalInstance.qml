import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.popups as WalletPopups
import AppLayouts.Wallet.stores as WalletStores

import shared.stores.send

import QtModelsToolkit

WalletPopups.ReceiveModal {
    id: root

    required property WalletStores.RootStore walletRootStore
    required property TransactionStore transactionStore

    // true when a single account or a saved address is shown, without the account switcher
    property bool fixedAccount
    property var fixedSelectedAccount

    ModelEntry {
        id: selectedReceiverAccount
        key: "address"
        sourceModel: root.transactionStore.accounts
        value: root.transactionStore.selectedReceiverAccountAddress
    }

    accounts: root.fixedAccount ? null : root.walletRootStore.accounts

    selectedAccount: {
        if (root.fixedAccount)
            return root.fixedSelectedAccount
        return selectedReceiverAccount.item ?? SQUtils.ModelUtils.get(root.transactionStore.accounts, 0)
    }

    onUpdateSelectedAddress: address => {
        if (!root.fixedAccount)
            root.transactionStore.setReceiverAccount(address)
    }
}
