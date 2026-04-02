import QtQuick

QtObject {
    id: root

    property var dappBrowserAccount: browserSectionCurrentAccount
    property var accounts: walletSectionAccounts.accounts
    property string defaultCurrency: walletSection.currentCurrency

    function switchAccountByAddress(address) {
        browserSectionCurrentAccount.switchAccountByAddress(address)
    }
}
