import QtQml

import utils

QtObject {
    id: root

    property bool knownPairingExists: false

    property string keycardState: ""
    property string keycardUid: ""
    property string keyUid: ""
    property bool keycardStatusAvailable: false
    property int remainingPinAttempts: -1
    property int remainingPukAttempts: -1
    property int availableSlots: -1
    property string cardMetadataWalletAccountsJson: "[]"

    readonly property bool hasKeyPair: !!root.keycardUid && !!root.keyUid

    readonly property bool onlyPinSet: !!root.keycardUid && !root.keyUid

    readonly property bool noKnownAndNoAvailablePairingSlots:
        root.keycardState === Constants.keycard.state.noAvailablePairingSlots
        || (!!root.keycardUid && root.availableSlots === 0 && !root.knownPairingExists)

    readonly property bool isBlockedPIN: !root.isEmpty
                                         && (root.keycardState === Constants.keycard.state.blockedPIN
                                             || !!root.keycardUid && root.keycardStatusAvailable && root.remainingPinAttempts === 0)

    readonly property bool isBlockedPUK: !root.isEmpty
                                         && (root.keycardState === Constants.keycard.state.blockedPUK
                                             || !!root.keycardUid && root.keycardStatusAvailable && root.remainingPukAttempts === 0)

    readonly property bool isEmpty: !root.noKnownAndNoAvailablePairingSlots
                                    && (root.keycardState === Constants.keycard.state.emptyKeycard
                                        || !root.keycardUid)

    readonly property var cardMetadataWalletAccounts: {
        try {
            // format: [ {"path": "m/../", "address": "0xabcd...", "publicKey": "ox1234..."} ]
            return JSON.parse(root.cardMetadataWalletAccountsJson)
        } catch (e) {
            console.warn("parsing card metadata wallet accounts: ", e.message)
            return []
        }
    }

    readonly property bool knownCardMetadata: {
        if (!root.hasKeyPair || root.cardMetadataWalletAccounts.length === 0) {
            return false
        }
        for (const acc of root.cardMetadataWalletAccounts) {
            if (!acc || !acc.address) {
                return false
            }
        }
        return true
    }
}
