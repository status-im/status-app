import QtQuick
import utils

import AppLayouts.Wallet
import StatusQ.Core

NotificationAdaptorCommunity {
    id: root

    // Token related properties:
    readonly property var tokenData: root.notification?.tokenData ?? null
    readonly property string tokenName: root.tokenData?.name ?? ""
    readonly property string tokenSymbol: root.tokenData?.symbol ?? ""
    readonly property string tokenAmount: {
        const amount = parseFloat(root.tokenData?.amount)
        return isNaN(amount) ? "1" : LocaleUtils.numberToLocaleString(amount)
    }

    // -------------------------
    // Navigation related
    // -------------------------
    redirectToSection: false
    redirectToWallet: true
}
