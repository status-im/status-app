import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Browser.provider.qml
import AppLayouts.Wallet
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import shared.popups.walletconnect

import utils

SQUtils.QObject {
    id: root

    // Parent item for the popups
    required property Item visualParent
    // Whether the dapps can interract with the wallet
    required property bool enabled
    /*
        Accounts model

        Expected model structure:
        name                    [string] - account name e.g. "Piggy Bank"
        address                 [string] - wallet account address e.g. "0x1234567890"
        colorizedChainPrefixes  [string] - chain prefixes with rich text colors e.g. "<font color=\"red\">eth:</font><font color=\"blue\">oeth:</font><font color=\"green\">arb:</font>"
        emoji                   [string] - emoji for account e.g. "🐷"
        colorId                 [string] - color id for account e.g. "1"
        currencyBalance         [var]    - fiat currency balance
            amount              [number] - amount of currency e.g. 1234
            symbol              [string] - currency symbol e.g. "USD"
            optDisplayDecimals  [number] - optional number of decimals to display
            stripTrailingZeroes [bool]   - strip trailing zeroes
        walletType              [string] - wallet type e.g. Constants.watchWalletType. See `Constants` for possible values
        migratedToColdWallet    [bool]   - whether account is migrated to cold wallet
        accountBalance          [var]    - account balance for a specific network
            formattedBalance    [string] - formatted balance e.g. "1234.56B"
            balance             [string] - balance e.g. "123456000000"
            iconUrl             [string] - icon url e.g. "network/hermez"
            chainColor          [string] - chain color e.g. "#FF0000"
    */
    property var accountsModel
    /*
      Networks model
      Expected model structure:
        chainName      [string]          - chain long name. e.g. "Ethereum" or "Optimism"
        chainId        [int]             - chain unique identifier
        iconUrl        [string]          - SVG icon name. e.g. "network/ethereum"
        layer          [int]             - chain layer. e.g. 1 or 2
        isTest         [bool]            - true if the chain is a testnet
    */
    property var networksModel
    /*
      ObjectModel containig session requests
        requestId     [string]                  - unique identifier for the request
        requestItem   [SessionRequestResolved]  - request object
    */
    property SessionRequestsModel sessionRequestsModel
    /*
      ObjectModel containing dApps
        name          [string] - dApp name
        iconUrl       [string] - dApp icon url
        dAppUrl       [string] - dApp url
        topic         [string] - dApp topic
    */
    property var dAppsModel

    property string selectedAccountAddress

    property var formatBigNumber: (number, symbol, noSymbolOption) => console.error("formatBigNumber not set")

    property bool walletConnectEnabled: true
    property bool connectorEnabled: true

    signal pairWCReady()

    signal disconnectRequested(string topic, string url, int connectorId, string clientId)
    signal pairingRequested(string uri)
    signal pairingValidationRequested(string uri)
    signal connectionAccepted(string pairingId, var chainIds, string selectedAccount)
    signal connectionDeclined(string pairingId)
    signal signRequestAccepted(string connectionId, string requestId)
    signal signRequestRejected(string connectionId, string requestId)
    signal signRequestIsLive(string connectionId, string requestId)
    signal pairWithConnectorRequested(int connectorId)

    /// Response to pairingValidationRequested
    function pairingValidated(validationState) {
        pairWC.instance?.pairingValidated(validationState)
    }

    /// Confirmation received on connectionAccepted
    function connectionSuccessful(pairingId, newConnectionId) {
        const modal = connectDapp.instance
        if (modal && modal.key === pairingId) {
            modal.topic = newConnectionId
            modal.pairSuccessful()
        }
    }

    /// Confirmation received on connectionAccepted
    function connectionFailed(pairingId) {
        const modal = connectDapp.instance
        if (modal && modal.key === pairingId)
            modal.pairFailed()
    }

    /// Request to connect to a dApp
    function connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorId, pairingId) {
        connectDapp.connect({ dappChains, dappUrl, dappName, dappIcon, connectorId, key: pairingId })
    }

    function openPairing() {
        pairWC.open(root)
        root.pairWCReady()
    }

    function chooseConnector() {
       dappConnectSelectLoader.active = true
    }

    function disconnectDapp(topic) {
        const dApp = SQUtils.ModelUtils.getByKey(root.dAppsModel, "topic", topic)
        confirmDisconnect.open(root, {
            topic,
            dappName: dApp?.name ?? "",
            dappIcon: dApp?.iconUrl ?? "",
            dappUrl: dApp?.url ?? "",
            connectorId: dApp?.connectorId ?? -1,
            clientId: dApp?.clientId || ""
        })
    }

    SQUtils.DeferredComponent {
        id: confirmDisconnect

        source: Qt.resolvedUrl("DAppConfirmDisconnectPopupInstance.qml")
        single: true
        destroyOnClose: true
        properties: ({ parent: root.visualParent })
        onCreated: popup => popup.disconnectRequested.connect(root.disconnectRequested)
    }

    SQUtils.DeferredComponent {
        id: pairWC

        module: "shared.popups.walletconnect"
        typeName: "PairWCModal"
        single: true
        destroyOnClose: true
        properties: ({ parent: root.visualParent })
        onCreated: modal => {
            modal.pair.connect(root.pairingRequested)
            modal.pairUriChanged.connect(root.pairingValidationRequested)
            modal.pairInstructionsRequested.connect(() => pairInstructions.open(root))
        }
    }

    SQUtils.DeferredComponent {
        id: pairInstructions

        module: "shared.popups.walletconnect"
        typeName: "DAppsUriCopyInstructionsPopup"
        single: true
        properties: ({ parent: root.visualParent })
    }

    SQUtils.DeferredComponent {
        id: connectDapp

        // requests that arrive while one is shown
        property var queue: []
        // the request shown once the pairing popup confirmed it
        property var pending: null

        source: Qt.resolvedUrl("ConnectDAppModalInstance.qml")
        single: true
        destroyOnClose: true
        properties: ({
            parent: root.visualParent,
            accounts: root.accountsModel,
            networksModel: root.networksModel,
            selectedAccountAddress: root.selectedAccountAddress,
            connectButtonEnabled: Qt.binding(() => root.enabled)
        })
        onCreated: modal => {
            modal.connectionAccepted.connect(root.connectionAccepted)
            modal.connectionDeclined.connect(root.connectionDeclined)
            modal.disconnectRequested.connect(root.disconnectRequested)
        }

        onInstanceChanged: {
            if (!connectDapp.instance && connectDapp.queue.length > 0)
                connectDapp.connect(connectDapp.queue.shift())
        }

        function connect(request) {
            console.log("[StatusConnect] DAppsWorkflow connect",
                         "key=" + request.key,
                         "url=" + request.dappUrl,
                         "connectorId=" + request.connectorId,
                         "chains=" + JSON.stringify(request.dappChains),
                         "modalShown=" + !!connectDapp.instance,
                         "queueLen=" + connectDapp.queue.length)
            if (connectDapp.instance) {
                connectDapp.queue.push(request)
                return
            }

            if (pairWC.instance) {
                // Allow user to get the uri valid confirmation
                connectDapp.pending = request
                pairWC.instance.pairingValidated(Pairing.errors.dappReadyForApproval)
                connectDappTimer.start()
            } else {
                connectDapp.show(request)
            }
        }

        function show(request) {
            connectDapp.open(root, {
                dappChains: request.dappChains,
                dAppUrl: request.dappUrl,
                dAppName: request.dappName,
                dAppIconUrl: request.dappIcon,
                dAppConnectorBadge: Constants.dappImageByType[request.connectorId] || "",
                dappConnectorId: request.connectorId,
                key: request.key
            })
        }
    }

    Instantiator {
        model: root.sessionRequestsModel
        delegate: QtObject {
            id: requestEntry

            required property var model
            required property int index

            // a child of this entry, so it goes with the entry when the request is removed
            property QtObject modal

            Component.onCompleted: modal = dappSignRequestModalComponent.createObject(requestEntry, {
                model: requestEntry.model,
                index: requestEntry.index
            })
        }

    }

    SQUtils.DeferredComponent {
        id: dappSignRequestModalComponent

        source: Qt.resolvedUrl("DAppSignRequestModalInstance.qml")
        properties: ({
            parent: root.visualParent,
            accountsModel: root.accountsModel,
            networksModel: root.networksModel,
            formatBigNumber: root.formatBigNumber,
            workflowEnabled: Qt.binding(() => root.enabled)
        })
        onCreated: modal => {
            modal.signRequestAccepted.connect(root.signRequestAccepted)
            modal.signRequestRejected.connect(root.signRequestRejected)
            modal.signRequestIsLive.connect(root.signRequestIsLive)
        }
    }

    Loader {
        id: dappConnectSelectLoader
        objectName: "dappConnectSelectLoader"
        active: false
        parent: root.visualParent
        sourceComponent: StatusDialog {
            id: dappConnectSelect
            objectName: "dappConnectSelect"
            width: 480
            topPadding: Theme.bigPadding
            leftPadding: Theme.padding
            rightPadding: Theme.padding
            bottomPadding: 4
            destroyOnClose: false
            visible: true

            title: qsTr("Connect a dApp")
            footer: StatusDialogFooter {
                bottomPadding: Theme.padding + dappConnectSelect.parent.SafeArea.margins.bottom
                rightButtons: ObjectModel {
                    StatusButton {
                        text: qsTr("Cancel")
                        onClicked: dappConnectSelect.close()
                    }
                }
            }

            contentItem: ColumnLayout {
                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.topMargin: Theme.padding
                    color: Theme.palette.baseColor1
                    text: qsTr("How would you like to connect?")
                }
                StatusListItem {
                    objectName: "btnStatusConnector"
                    title: "Status Connector"
                    asset.name: Assets.png("status-logo")
                    asset.isImage: true
                    visible: root.connectorEnabled
                    enabled: root.connectorEnabled
                    components: [
                        StatusIcon {
                            icon: "external-link"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: {
                        dappConnectSelect.close()
                        root.pairWithConnectorRequested(Constants.DAppConnectors.StatusConnect)
                    }
                }
                StatusListItem {
                    objectName: "btnWalletConnect"
                    title: "Wallet Connect"
                    asset.name: Assets.svg("walletconnect")
                    asset.isImage: true
                    enabled: root.walletConnectEnabled
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: {
                        dappConnectSelect.close()
                        root.pairWithConnectorRequested(Constants.DAppConnectors.WalletConnect)
                    }
                    Layout.bottomMargin: Theme.padding
                }
            }
            onClosed: dappConnectSelectLoader.active = false
        }
    }

    // Used between transitioning from PairWCModal to ConnectDAppModal
    Timer {
        id: connectDappTimer

        interval: 500
        running: false
        repeat: false

        onTriggered: {
            pairWC.instance?.close()
            const request = connectDapp.pending
            connectDapp.pending = null
            if (request)
                connectDapp.show(request)
        }
    }
}
