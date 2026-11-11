import shared.popups.addaccount

// Loaded by URL (see WalletLayout), so AddAccountPopup is not part of the wallet's type closure
AddAccountPopup {
    id: root

    required property var addAccountModule

    store.addAccountModule: root.addAccountModule
}
