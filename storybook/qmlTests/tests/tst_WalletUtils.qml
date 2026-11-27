import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet
import utils

TestCase {
    name: "WalletUtils"

    readonly property string address: "0x1cd2a8f3b4e5d6c7a8b9c0d1e2f3a4b5c6d712b5"

    function test_ownAddressToDisplay() {
        compare(WalletUtils.ownAddressToDisplay(address, false), address)
        compare(WalletUtils.ownAddressToDisplay(address, true), SQUtils.Utils.elideAndFormatWalletAddress(address))
    }

    function test_isOwnedAccount() {
        verify(WalletUtils.isOwnedAccount({ walletType: "" }))
        verify(WalletUtils.isOwnedAccount({ walletType: "seed" }))
        verify(WalletUtils.isOwnedAccount({ walletType: "key" }))
        verify(!WalletUtils.isOwnedAccount({ walletType: Constants.watchWalletType }))
        verify(!WalletUtils.isOwnedAccount(null))
    }

    // Only a wallet account row can be owned: saved addresses and other people's accounts are not
    function test_isOwnedAccountNeedsAWalletAccount() {
        verify(!WalletUtils.isOwnedAccount({ address: "0x1", name: "Saved", ens: "" }))
        verify(!WalletUtils.isOwnedAccount({ address: "0x1", name: "Contact's account", colorId: "primary" }))
        verify(!WalletUtils.revealNeedsPassword({ address: "0x1", name: "Saved" }, true))
    }

    // Only addresses of the profile password's key pairs are hidden until a password is set
    function test_revealNeedsPassword_data() {
        return [
            { tag: "profile account", account: { walletType: "" }, needs: true, expected: true },
            { tag: "imported key pair", account: { walletType: "seed" }, needs: true, expected: true },
            { tag: "watch-only", account: { walletType: Constants.watchWalletType }, needs: true, expected: false },
            { tag: "cold wallet", account: { walletType: "", migratedToColdWallet: true }, needs: true, expected: false },
            { tag: "password set", account: { walletType: "" }, needs: false, expected: false },
            { tag: "no account", account: null, needs: true, expected: false },
        ]
    }
    function test_revealNeedsPassword(data) {
        compare(WalletUtils.revealNeedsPassword(data.account, data.needs), data.expected)
    }
}
