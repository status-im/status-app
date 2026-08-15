import QtQuick

// Required mock of: src/app/modules/main/wallet_section/accounts/view.nim
//
// `accounts` carries every role of accounts/model.nim. Empty by default;
// WalletSectionMock.install() swaps in the generated model.

Item {
    id: root

    readonly property string contextPropertyName: "walletSectionAccounts"

    property var accounts: emptyAccounts

    readonly property ListModel emptyAccounts: ListModel {}

    // Set by WalletSectionMock so the by-address lookups resolve against the
    // generated profile instead of returning placeholders.
    property var profile: null

    function _row(address) {
        if (!root.profile)
            return null
        const account = root.profile.accountByAddress(address)
        return account && account.address ? account : null
    }

    function getNameByAddress(address) {
        const row = _row(address)
        return row ? row.name : "Name Mock " + address.substring(0, 5)
    }

    function getEmojiByAddress(address) {
        const row = _row(address)
        return row ? row.emoji : ""
    }

    function getColorByAddress(address) {
        const row = _row(address)
        return row ? row.colorId : 0
    }

    function isOwnedAccount(address) {
        return !!_row(address)
    }

    function getWalletAccountAsJson(address) {
        const row = _row(address)
        return row ? JSON.stringify(row) : "null"
    }

    function deleteAccount(address, password) {}
    function updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance) {}
}
