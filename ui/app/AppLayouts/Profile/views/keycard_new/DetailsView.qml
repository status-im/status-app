import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Profile.stores 1.0 as ProfileStores

import shared.popups.keycard_new.helpers 1.0

import shared.status

import utils

ColumnLayout {
    id: root

    required property ProfileStores.KeycardNewStore keycardStore

    property bool areTestNetworksEnabled: false

    property string keycardState: ""
    property string keycardUid: ""
    property string keyUid: ""
    property int remainingPinAttempts: -1
    property int remainingPukAttempts: -1
    property int availableSlots: -1
    property string cardMetadataName: ""
    property string cardMetadataWalletAccountsJson: "[]"

    readonly property string detailsScreenTitle: d.detailsTitle

    spacing: Constants.settingsSection.itemSpacing

    // Used to refresh properties since no bindings on a plain functions
    function refresh() {
        d.refresh()
    }

    onKeyUidChanged: d.refresh()

    onKeycardUidChanged: d.refresh()

    QtObject {
        id: d

        readonly property bool isProfileKeyPair: !!root.keyUid
                                                 && root.keyUid === root.keycardStore.userProfileKeyUid

        readonly property bool hasKeyPair: !!root.keycardUid && !!root.keyUid

        readonly property bool onlyPinSet: !!root.keycardUid && !root.keyUid

        // pairing slot has the highest priority, cause the keycard cannot be read if the pairing doesn't exist or a new pairing cannot be made
        readonly property bool noKnownAndNoAvailablePairingSlots: root.keycardState === Constants.keycard.state.noAvailablePairingSlots
                                                                  || (!!root.keycardUid && root.availableSlots === 0 && !d.pairingExists)

        readonly property bool isBlockedPIN: !d.isEmpty
                                             && (root.keycardState === Constants.keycard.state.blockedPIN
                                                 || !!root.keycardUid && root.remainingPinAttempts === 0)

        readonly property bool isBlockedPUK: !d.isEmpty
                                             && (root.keycardState === Constants.keycard.state.blockedPUK
                                                 || !!root.keycardUid && root.remainingPukAttempts <= 0)

        readonly property bool isEmpty: !d.noKnownAndNoAvailablePairingSlots
                                        && (root.keycardState === Constants.keycard.state.emptyKeycard
                                            || !root.keycardUid)

        readonly property bool knownCardMetadata: {
            if (!d.hasKeyPair || d.cardMetadataWalletAccounts.length === 0) {
                return false
            }

            let allAddressesKnown = true
            for (const acc of d.cardMetadataWalletAccounts) {
                if (!acc || !acc.address) {
                    allAddressesKnown = false
                    break
                }
            }
            return allAddressesKnown
        }

        readonly property var cardMetadataWalletAccounts: {
            try {
                // format: [ {"path": "m/../", "address": "0xabcd...", "publicKey": "ox1234..."} ]
                return JSON.parse(root.cardMetadataWalletAccountsJson)
            } catch (e) {
                console.warn("parsing card metadata wallet accounts: ", e.message)
                return []
            }
        }

        property bool pairingExists: false
        property bool isKnownKeyPair: false
        property bool allNonProfileKeyPairsMigrated: false

        function refresh() {
            d.pairingExists = !!root.keycardUid
                              && root.keycardStore.keycardPairingExists(root.keycardUid)
            d.isKnownKeyPair = d.hasKeyPair
                               && root.keycardStore.isKnownKeyUid(root.keyUid)
            d.allNonProfileKeyPairsMigrated = root.keycardStore.allNonProfileKeyPairsMigratedToKeycard()

            root.keycardStore.resolveKeyPairItemForKeyUid(root.keyUid)
        }

        readonly property string detailsTitle: {
            if (d.noKnownAndNoAvailablePairingSlots) {
                return qsTr("No free pairing slots")
            }
            if (d.isEmpty) {
                return qsTr("Keycard is empty")
            }
            if (d.isBlockedPIN || d.isBlockedPUK) {
                return qsTr("Keycard is blocked")
            }
            if (d.onlyPinSet) {
                return qsTr("Keycard stores only PIN")
            }
            if (d.isProfileKeyPair) {
                return qsTr("Keycard stores Status profile key pair")
            }
            if (d.hasKeyPair) {
                return qsTr("Keycard stores key pair")
            }

            return qsTr("Keycard")
        }

        readonly property string info: {
            if (d.noKnownAndNoAvailablePairingSlots) {
                return qsTr("You can’t operate with Keycard content right now, because Keycard has no free pairing slots. But you can use it with previously paired installations.")
            }
            if (d.isBlockedPUK) {
                return qsTr("Keycard is blocked due to five failed PUK input attempts")
            }
            if (d.isBlockedPIN) {
                return qsTr("Keycard is blocked due to three failed PIN input attempts")
            }
            if (d.isProfileKeyPair) {
                return qsTr("You are using this Keycard to login to Status")
            }
            if (d.isKnownKeyPair) {
                return qsTr("This key pair have been already added to Status wallet")
            }
            if (d.hasKeyPair) {
                return qsTr("Key pair has not been added to Status wallet")
            }

            return ""
        }

        function startFlow(flow) {
            Global.openKeycardManagementPopup(flow,
                                              root.keyUid,
                                              root.keycardUid,
                                              root.cardMetadataName,
                                              root.cardMetadataWalletAccountsJson)
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        color: Theme.palette.baseColor1
        wrapMode: Text.WordWrap
        visible: !!text
        text: {
            let finalText = ""
            if (!!root.cardMetadataName) {
                finalText = root.cardMetadataName
            }

            if (!!root.keycardUid) {
                if (!!finalText) {
                    finalText += qsTr(", ")
                }
                finalText += qsTr("UID: %1").arg(root.keycardUid)
            }

            return finalText
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        Layout.topMargin: Theme.xlPadding
        color: Theme.palette.baseColor1
        wrapMode: Text.WordWrap
        visible: !!text
        text: d.info
    }

    KeyPairItem {
        Layout.fillWidth: true
        Layout.topMargin: Theme.padding
        visible: d.isProfileKeyPair
                 || d.isKnownKeyPair
                 || d.hasKeyPair && d.knownCardMetadata

        isKnownKeyPair: d.isKnownKeyPair

        userProfileKeyUid: root.keycardStore.userProfileKeyUid
        userProfileColor: Utils.colorForPubkey(Theme.palette, root.keycardStore.userProfilePubKey)

        keyPairKeyUid: root.keyUid
        keyPairMigratedToKeycard: root.keycardStore.keyPairItem.migratedToKeycard
        keyPairName: root.keycardStore.keyPairItem.name
        keyPairIcon: root.keycardStore.keyPairItem.icon
        keyPairImage: root.keycardStore.keyPairItem.image
        keyPairCardLocked: d.isBlockedPIN || d.isBlockedPUK
        areTestNetworksEnabled: root.areTestNetworksEnabled
        keyPairAccounts: d.isKnownKeyPair? root.keycardStore.keyPairItem.accounts : d.cardMetadataWalletAccounts
        keyPairLocation: d.isKnownKeyPair? Utils.getKeypairLocation(root.keycardStore.keyPairItem, false) : ""
        keyPairLocationColor: d.isKnownKeyPair? Utils.getKeypairLocationColor(Theme.palette, root.keycardStore.keyPairItem) : ""
    }

    StatusSectionHeadline {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        Layout.topMargin: Theme.xlPadding
        text: qsTr("What you can do:")
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: !root.keycardStore.isKeycardUser
                 && (d.isEmpty
                     || d.onlyPinSet && !d.isBlockedPIN && !d.isBlockedPUK  && !d.noKnownAndNoAvailablePairingSlots)
        title: qsTr("Move profile key pair to Keycard")
        subTitle: qsTr("Keycard will be required for signing and logging in to Status")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            d.startFlow(Constants.keycard.flow.moveProfileKeyPair)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: !d.allNonProfileKeyPairsMigrated
                 && (d.isEmpty
                     || d.onlyPinSet && !d.isBlockedPIN && !d.isBlockedPUK  && !d.noKnownAndNoAvailablePairingSlots)
        title: qsTr("Move key pair from Status wallet to Keycard")
        subTitle: qsTr("Keycard will be required for signing")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            d.startFlow(Constants.keycard.flow.moveKeyPair)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.isEmpty
                 || d.onlyPinSet && !d.isBlockedPIN && !d.isBlockedPUK  && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Import a new key pair to Keycard")
        subTitle: qsTr("Keycard will be required for signing")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            if (root.keycardStore.remainingKeypairCapacity() === 0) {
                Global.openLimitReachedPopup(Constants.LimitWarning.Keypairs)
                return
            }
            d.startFlow(Constants.keycard.flow.importNewKeyPair)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.isEmpty
                 || d.onlyPinSet && !d.isBlockedPIN && !d.isBlockedPUK  && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Import a key pair from recovery phrase")
        subTitle: qsTr("In case you lost Keycard, want to create a backup or import a\nkey pair. Keycard will be required for signing")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            d.startFlow(Constants.keycard.flow.importSeedPhrase)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.isBlockedPIN
                 || d.isBlockedPUK
        title: qsTr("Unblock with recovery phrase")
        subTitle: qsTr("Requires providing the recovery phrase for the key pair stored on Keycard")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            console.warn("TODO: unblock with recovery phrase flow...")
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.isBlockedPIN
        title: qsTr("Unblock with PUK")
        subTitle: qsTr("If you set your PUK earlier for this Keycard")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            console.warn("TODO: unblock with puk flow...")
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.hasKeyPair
                 && !d.isKnownKeyPair
                 && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Add key pair to Status wallet")
        subTitle: qsTr("You’ll be able to sign transactions in Status wallet with Keycard")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            if (root.keycardStore.remainingKeypairCapacity() === 0) {
                Global.openLimitReachedPopup(Constants.LimitWarning.Keypairs)
                return
            }
            d.startFlow(Constants.keycard.flow.addKeyPairToStatus)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: (d.hasKeyPair
                  || d.onlyPinSet)
                 && !d.isBlockedPIN
                 && !d.isBlockedPUK
                 && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Change PIN")
        subTitle: qsTr("If you want to have a different PIN")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            d.startFlow(Constants.keycard.flow.changePin)
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: (d.hasKeyPair
                  || d.onlyPinSet)
                 && !d.isBlockedPIN
                 && !d.isBlockedPUK
                 && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Rename")
        subTitle: qsTr("New name will be visible in Status and in other apps")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            console.warn("TODO: rename keycard flow...")
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: (d.hasKeyPair
                  || d.onlyPinSet)
                 && !d.isBlockedPIN
                 && !d.isBlockedPUK
                 && !d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Set or change PUK")
        subTitle: qsTr("If you want an additional recovery option")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            console.warn("TODO: change puk flow...")
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        visible: d.hasKeyPair
                 || d.onlyPinSet
                 || d.noKnownAndNoAvailablePairingSlots
        title: qsTr("Factory reset Keycard")
        subTitle: qsTr("Remove everything from Keycard")
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            d.startFlow(Constants.keycard.flow.factoryReset)
        }
    }
}
