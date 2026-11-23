import QtQuick

import StatusQ.Core.Theme

import AppLayouts.Wallet.stores

import shared.popups

import utils

RemoveAccountConfirmationPopup {
    id: root

    required property string colorId
    required property bool migratedToColdWallet
    required property string authenticationRequestId

    signal authenticationRequested()
    signal deletionRequested(string password)

    color: Utils.getColorForId(Theme.palette, root.colorId)

    function doDeletion(password) {
        root.close()
        root.deletionRequested(password)
    }

    onRemoveAccount: {
        if (root.accountType === Constants.watchWalletType || root.migratedToColdWallet) {
            root.doDeletion("")
            return
        }
        root.authenticationRequested()
    }

    Connections {
        target: RootStore

        function onLoggedInUserAuthenticated(requestedBy: string, password: string, pin: string, keyUid: string, keycardUid: string) {
            if (root.authenticationRequestId !== requestedBy || password === "")
                return
            root.doDeletion(password)
        }
    }
}
