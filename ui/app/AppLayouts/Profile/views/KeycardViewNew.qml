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
            Global.openKeycardManagementPopup(Constants.keycard.flow.readKeycard, keyUid, keycardUid)
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
            property int remainingPinAttempts: -1
            property int remainingPukAttempts: -1
            property int availableSlots: -1
            property string cardMetadataName: ""
            property string cardMetadataWalletAccountsJson: "[]"

            function showDetails(keycardState, keycardUid, keyUid, remainingPinAttempts, remainingPukAttempts,
                                 availableSlots, cardMetadataName, cardMetadataWalletAccountsJson) {
                d.keycardState = keycardState
                d.keycardUid = keycardUid
                d.keyUid = keyUid
                d.remainingPinAttempts = remainingPinAttempts
                d.remainingPukAttempts = remainingPukAttempts
                d.availableSlots = availableSlots
                d.cardMetadataName = cardMetadataName
                d.cardMetadataWalletAccountsJson = cardMetadataWalletAccountsJson

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
            remainingPinAttempts: d.remainingPinAttempts
            remainingPukAttempts: d.remainingPukAttempts
            availableSlots: d.availableSlots
            cardMetadataName: d.cardMetadataName
            cardMetadataWalletAccountsJson: d.cardMetadataWalletAccountsJson
        }
    }

    Connections {
        target: Global

        function onKeycardManagementResult(keycardState, keycardUid, keyUid, remainingPinAttempts, remainingPukAttempts,
                                           availableSlots, cardMetadataName, cardMetadataWalletAccountsJson) {
            d.showDetails(keycardState, keycardUid, keyUid, remainingPinAttempts, remainingPukAttempts,
                          availableSlots, cardMetadataName, cardMetadataWalletAccountsJson)
        }
    }
}
