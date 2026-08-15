import QtQuick

import shared.stores.send

/*!
    The slice of the real `shared.stores.send.TransactionStore` that the wallet
    section and its popups actually touch, backed by the generated profile.

    `TransactionStoreMock` cannot serve here: it hard-codes its own accounts and
    saved addresses, so the send/receive flows would show a different wallet than
    the section behind them.
*/
TransactionStore {
    id: root

    readonly property var accounts: walletSectionAccounts.accounts
    readonly property var tempActivityController1Model: walletSection.tmpActivityController1.model

    property string selectedReceiverAccountAddress: ""
    property string selectedSenderAccountAddress: ""

    function setReceiverAccount(address) {
        root.selectedReceiverAccountAddress = address
    }

    function setSenderAccount(address) {
        root.selectedSenderAccountAddress = address
    }
}
