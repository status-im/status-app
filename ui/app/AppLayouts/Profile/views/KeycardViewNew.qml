import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Profile.stores 1.0 as ProfileStores

import utils

import "./keycard_new"

SettingsContentBase {
    id: root

    objectName: "settings_KeycardView"

    required property ProfileStores.KeycardNewStore keycardNewStore

    property bool areTestNetworksEnabled: false

    property string mainSectionTitle: ""

    signal backButtonNameRequested(string name)

    titleRowComponentLoader.sourceComponent: StatusButton {
        objectName: "settings_Keycard_ReadKeycardButton"
        text: qsTr("Read Keycard")
        visible: stackLayout.currentIndex === d.mainViewIndex
        onClicked: {
            const keyUid = ""
            const keycardUid = ""
            const cardMetadataName = ""
            const cardMetadataWalletAccountsJson = "[]"
            const keycardInitialized = false
            Global.openKeycardManagementPopup(Constants.keycard.flow.readKeycard, keyUid, keycardUid, cardMetadataName,
                                              cardMetadataWalletAccountsJson, keycardInitialized)
        }
    }

    function handleBackAction() {
        if (stackLayout.currentIndex === d.detailsViewIndex) {
            stackLayout.currentIndex = d.mainViewIndex
            root.sectionTitle = root.mainSectionTitle
            root.backButtonNameRequested("")
        }
    }

    StackLayout {
        id: stackLayout

        width: root.contentWidth
        currentIndex: d.mainViewIndex

        QtObject {
            id: d

            readonly property int mainViewIndex: 0
            readonly property int detailsViewIndex: 1

            property string keycardState: ""
            property string keycardUid: ""
            property bool keycardInitialized: false
            property string keyUid: ""
            property bool keycardStatusAvailable: false
            property int remainingPinAttempts: -1
            property int remainingPukAttempts: -1
            property int availableSlots: -1
            property bool pairingSupported: true
            property bool certificateTrusted: true
            property string cardMetadataName: ""
            property string cardMetadataWalletAccountsJson: "[]"

            function showMainScreen() {
                stackLayout.currentIndex = d.mainViewIndex
                root.sectionTitle = root.mainSectionTitle
                root.backButtonNameRequested("")
            }

            function showDetailsScreen(keycardInfo) {
                d.keycardState = keycardInfo.keycardState
                d.keycardUid = keycardInfo.keycardUid
                d.keycardInitialized = keycardInfo.keycardInitialized
                d.keyUid = keycardInfo.keyUid
                d.keycardStatusAvailable = keycardInfo.keycardStatusAvailable
                d.remainingPinAttempts = keycardInfo.remainingPinAttempts
                d.remainingPukAttempts = keycardInfo.remainingPukAttempts
                d.availableSlots = keycardInfo.availableSlots
                d.pairingSupported = keycardInfo.pairingSupported
                d.certificateTrusted = keycardInfo.certificateTrusted
                d.cardMetadataName = keycardInfo.cardMetadataName
                d.cardMetadataWalletAccountsJson = keycardInfo.cardMetadataWalletAccountsJson

                detailsView.refresh()

                root.sectionTitle = detailsView.detailsScreenTitle
                root.backButtonNameRequested(root.mainSectionTitle)
                stackLayout.currentIndex = d.detailsViewIndex
            }
        }

        MainView {
            Layout.preferredWidth: root.contentWidth
        }

        DetailsView {
            id: detailsView
            Layout.preferredWidth: root.contentWidth

            keycardStore: root.keycardNewStore

            areTestNetworksEnabled: root.areTestNetworksEnabled

            keycardState: d.keycardState
            keycardUid: d.keycardUid
            keycardInitialized: d.keycardInitialized
            keyUid: d.keyUid
            keycardStatusAvailable: d.keycardStatusAvailable
            remainingPinAttempts: d.remainingPinAttempts
            remainingPukAttempts: d.remainingPukAttempts
            availableSlots: d.availableSlots
            pairingSupported: d.pairingSupported
            certificateTrusted: d.certificateTrusted
            cardMetadataName: d.cardMetadataName
            cardMetadataWalletAccountsJson: d.cardMetadataWalletAccountsJson
        }
    }

    Connections {
        target: Global

        function onKeycardManagementResult(keycardInfo) {
            d.showDetailsScreen(keycardInfo)
        }

        function onKeycardFlowDone(flow, keyUid, keycardUid, success) {
            switch(flow) {
            case Constants.keycard.flow.readKeycard:
                console.info("reading keycard - keyUid: ", keyUid, " keycardUid: ", keycardUid," done successfully: ", success)
                return
            case Constants.keycard.flow.factoryReset:
                console.info("resetting keycard done successfully: ", success)
                break
            case Constants.keycard.flow.importSeedPhrase:
                console.info("importing key pair via seed phrase - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.importNewKeyPair:
                console.info("importing a new key pair - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.moveKeyPair:
                console.info("migrating key pair to keycard - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.moveProfileKeyPair:
                console.info("migrating a profile key pair to keycard - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.addKeyPairToStatus:
                console.info("adding key pair from keycard - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.changePin:
                console.info("changing keycard PIN - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.setOrChangePuk:
                console.info("setting keycard PUK - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.rename:
                console.info("renaming keycard - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.unblockWithPuk:
                console.info("unblocking keycard with PUK - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            case Constants.keycard.flow.unblockWithRecoveryPhrase:
                console.info("unblocking keycard with recovery phrase - keyUid: ", keyUid, " keycardUid: ", keycardUid, " done successfully: ", success)
                break
            }

            d.showMainScreen()
        }
    }
}
