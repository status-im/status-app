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
        if (pairWCLoader.item) {
            pairWCLoader.item.pairingValidated(validationState)
        }
    }

    /// Confirmation received on connectionAccepted
    function connectionSuccessful(pairingId, newConnectionId) {
        connectDappLoader.connectionSuccessful(pairingId, newConnectionId)
    }

    /// Confirmation received on connectionAccepted
    function connectionFailed(pairingId) {
        connectDappLoader.connectionFailed(pairingId)
    }

    /// Request to connect to a dApp
    function connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorId, pairingId) {
        connectDappLoader.connect(dappChains, dappUrl, dappName, dappIcon, connectorId, pairingId)
    }

    function openPairing() {
        pairWCLoader.active = true
    }

    function chooseConnector() {
       dappConnectSelectLoader.active = true
    }

    function disconnectDapp(topic) {
        disconnectdAppDialogLoader.dAppTopic = topic
        disconnectdAppDialogLoader.active = true
    }

    Loader {
        id: disconnectdAppDialogLoader

        property string dAppTopic
        property string dAppUrl: ""
        property int dAppConnectorId: -1
        property string dAppClientId: ""

        active: false
        parent: root.visualParent

        onLoaded: {
            const dApp = SQUtils.ModelUtils.getByKey(root.dAppsModel, "topic", dAppTopic);
            if (dApp) {
                item.dappName = dApp.name;
                item.dappIcon = dApp.iconUrl;
                item.dappUrl = dApp.url;
                dAppUrl = dApp.url;
                dAppConnectorId = dApp.connectorId;
                dAppClientId = dApp.clientId || "";
            }

            item.closed.connect(() => disconnectdAppDialogLoader.active = false)
            item.accepted.connect(() => {
                root.disconnectRequested(disconnectdAppDialogLoader.dAppTopic, disconnectdAppDialogLoader.dAppUrl, disconnectdAppDialogLoader.dAppConnectorId, disconnectdAppDialogLoader.dAppClientId)
            })
            item.open();
        }

        source: Qt.resolvedUrl("../../../../../imports/shared/popups/walletconnect/DAppConfirmDisconnectPopup.qml")
    }

    Loader {
        id: pairWCLoader

        active: false
        parent: root.visualParent

        onLoaded: {
            item.closed.connect(() => pairWCLoader.active = false)
            item.pair.connect(uri => root.pairingRequested(uri))
            item.pairUriChanged.connect(uri => root.pairingValidationRequested(uri))
            item.pairInstructionsRequested.connect(() => pairInstructionsLoader.active = true)
            item.open()
            root.pairWCReady()
        }

        source: Qt.resolvedUrl("../../../../../imports/shared/popups/walletconnect/PairWCModal.qml")
    }

    Loader {
        id: pairInstructionsLoader

        active: false
        parent: root.visualParent

        source: Qt.resolvedUrl("../../../../../imports/shared/popups/walletconnect/DAppsUriCopyInstructionsPopup.qml")

        onLoaded: {
            item.destroyOnClose = false
            item.closed.connect(() => pairInstructionsLoader.active = false)
            item.open()
        }
    }

    Loader {
        id: connectDappLoader

        active: false
        parent: root.visualParent

        // Array of chaind ids
        property var dappChains
        property url dappUrl
        property string dappName
        property url dappIcon
        property string connectorIcon
        property int dappConnectorId: Constants.DAppConnectors.WalletConnect
        property var key
        property var topic

        property bool connectRequestHandled: false

        function resolve(action) {
            connectRequestHandled = true
            action()
        }

        property var connectionQueue: []
        onActiveChanged: {
            if (!active && connectionQueue.length > 0) {
                connect(connectionQueue[0].dappChains,
                        connectionQueue[0].dappUrl,
                        connectionQueue[0].dappName,
                        connectionQueue[0].dappIcon,
                        connectionQueue[0].connectorId,
                        connectionQueue[0].key)
                connectionQueue.shift()
            }
        }

        function connect(dappChains, dappUrl, dappName, dappIcon, connectorId, key) {
            console.log("[StatusConnect] DAppsWorkflow connect",
                         "key=" + key,
                         "url=" + dappUrl,
                         "connectorId=" + connectorId,
                         "chains=" + JSON.stringify(dappChains),
                         "loaderActive=" + connectDappLoader.active,
                         "queueLen=" + connectionQueue.length)
            if (connectDappLoader.active) {
                connectionQueue.push({ dappChains, dappUrl, dappName, dappIcon, connectorId, key })
                return
            }

            connectDappLoader.connectRequestHandled = false
            connectDappLoader.dappChains = dappChains
            connectDappLoader.dappUrl = dappUrl
            connectDappLoader.dappName = dappName
            connectDappLoader.dappIcon = dappIcon
            connectDappLoader.connectorIcon = Constants.dappImageByType[connectorId] || ""
            connectDappLoader.dappConnectorId = connectorId
            connectDappLoader.key = key

            if (pairWCLoader.item) {
                // Allow user to get the uri valid confirmation
                pairWCLoader.item.pairingValidated(Pairing.errors.dappReadyForApproval)
                connectDappTimer.start()
            } else {
                connectDappLoader.active = true
            }
        }

        function connectionSuccessful(key, newTopic) {
            if (connectDappLoader.key === key && connectDappLoader.item) {
                connectDappLoader.topic = newTopic
                connectDappLoader.item.pairSuccessful()
            }
        }

        function connectionFailed(id) {
            if (connectDappLoader.key === id && connectDappLoader.item) {
                connectDappLoader.item.pairFailed()
            }
        }

        Component.onCompleted: setSource(Qt.resolvedUrl("ConnectDAppModalInstance.qml"),
                                         { workflow: root, loader: connectDappLoader })
    }

    Instantiator {
        model: root.sessionRequestsModel
        delegate: QtObject {
            id: requestEntry

            required property var model
            required property int index

            // a child of this entry, so it goes with the entry when the request is removed
            readonly property QtObject modal: dappSignRequestModalComponent.createObject(requestEntry, {
                host: root,
                model: requestEntry.model,
                index: requestEntry.index
            })
        }

    }

    SQUtils.DeferredComponent {
        id: dappSignRequestModalComponent

        source: Qt.resolvedUrl("DAppSignRequestModalInstance.qml")
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
            pairWCLoader.item.close()
            connectDappLoader.active = true
        }
    }
}
