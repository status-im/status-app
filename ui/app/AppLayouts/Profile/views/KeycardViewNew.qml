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

    required property ProfileStores.KeycardNewStore keycardNewStore

    property bool areTestNetworksEnabled: false

    property string mainSectionTitle: ""

    signal backButtonNameRequested(string name)

    titleRowComponentLoader.sourceComponent: StatusButton {
        text: qsTr("Read Keycard")
        visible: stackLayout.currentIndex === d.mainViewIndex
        onClicked: {
            const keyUid = ""
            const keycardUid = ""
            const cardMetadataName = ""
            const cardMetadataWalletAccountsJson = "[]"
            Global.openKeycardManagementPopup(Constants.keycard.flow.readKeycard, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
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
            property string keyUid: ""
            property bool keycardStatusAvailable: false
            property int remainingPinAttempts: -1
            property int remainingPukAttempts: -1
            property int availableSlots: -1
            property string cardMetadataName: ""
            property string cardMetadataWalletAccountsJson: "[]"

            function showMainScreen() {
                stackLayout.currentIndex = d.mainViewIndex
                root.sectionTitle = root.mainSectionTitle
                root.backButtonNameRequested("")
            }

            function showDetailsScreen(keycardState, keycardUid, keyUid, keycardStatusAvailable, remainingPinAttempts,
                                       remainingPukAttempts, availableSlots, cardMetadataName, cardMetadataWalletAccountsJson) {
                d.keycardState = keycardState
                d.keycardUid = keycardUid
                d.keyUid = keyUid
                d.keycardStatusAvailable = keycardStatusAvailable
                d.remainingPinAttempts = remainingPinAttempts
                d.remainingPukAttempts = remainingPukAttempts
                d.availableSlots = availableSlots
                d.cardMetadataName = cardMetadataName
                d.cardMetadataWalletAccountsJson = cardMetadataWalletAccountsJson

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
            keyUid: d.keyUid
            keycardStatusAvailable: d.keycardStatusAvailable
            remainingPinAttempts: d.remainingPinAttempts
            remainingPukAttempts: d.remainingPukAttempts
            availableSlots: d.availableSlots
            cardMetadataName: d.cardMetadataName
            cardMetadataWalletAccountsJson: d.cardMetadataWalletAccountsJson
        }
    }

    Connections {
        target: Global

        function onKeycardManagementResult(keycardState, keycardUid, keyUid, keycardStatusAvailable, remainingPinAttempts,
                                           remainingPukAttempts, availableSlots, cardMetadataName, cardMetadataWalletAccountsJson) {
            d.showDetailsScreen(keycardState, keycardUid, keyUid, keycardStatusAvailable, remainingPinAttempts, remainingPukAttempts,
                                availableSlots, cardMetadataName, cardMetadataWalletAccountsJson)
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
