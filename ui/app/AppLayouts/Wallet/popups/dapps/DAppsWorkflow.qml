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
    // Values mapped to Constants.LoginType
    required property int loginType
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
        migratedToKeycard       [bool]   - whether account is migrated to keycard
        accountBalance          [var]    - account balance for a specific network
            formattedBalance    [string] - formatted balance e.g. "1234.56B"
            balance             [string] - balance e.g. "123456000000"
            iconUrl             [string] - icon url e.g. "network/Network=Hermez"
            chainColor          [string] - chain color e.g. "#FF0000"
    */
    property var accountsModel
    /*
      Networks model
      Expected model structure:
        chainName      [string]          - chain long name. e.g. "Ethereum" or "Optimism"
        chainId        [int]             - chain unique identifier
        iconUrl        [string]          - SVG icon name. e.g. "network/Network=Ethereum"
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
    function connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorIcon, pairingId) {
        connectDappLoader.connect(dappChains, dappUrl, dappName, dappIcon, connectorIcon, pairingId)
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

            item.open();
        }

        sourceComponent: DAppConfirmDisconnectPopup {

            visible: true

            onClosed: {
                disconnectdAppDialogLoader.active = false
            }

            onAccepted: {
                root.disconnectRequested(disconnectdAppDialogLoader.dAppTopic, disconnectdAppDialogLoader.dAppUrl, disconnectdAppDialogLoader.dAppConnectorId, disconnectdAppDialogLoader.dAppClientId)
            }
        }
    }

    Loader {
        id: pairWCLoader

        active: false
        parent: root.visualParent

        onLoaded: {
            item.open()
            root.pairWCReady()
        }

        sourceComponent: PairWCModal {
            visible: true

            onClosed: pairWCLoader.active = false
            onPair: (uri) => root.pairingRequested(uri)
            onPairUriChanged: (uri) => root.pairingValidationRequested(uri)
            onPairInstructionsRequested: pairInstructionsLoader.active = true
        }
    }

    Loader {
        id: pairInstructionsLoader

        active: false
        parent: root.visualParent

        sourceComponent: Component {
            DAppsUriCopyInstructionsPopup{
                visible: true
                destroyOnClose: false
                onClosed: pairInstructionsLoader.active = false
            }
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
        property var key
        property var topic

        property var connectionQueue: []
        onActiveChanged: {
            if (!active && connectionQueue.length > 0) {
                connect(connectionQueue[0].dappChains,
                        connectionQueue[0].dappUrl,
                        connectionQueue[0].dappName,
                        connectionQueue[0].dappIcon,
                        connectionQueue[0].connectorIcon,
                        connectionQueue[0].key)
                connectionQueue.shift()
            }
        }

        function connect(dappChains, dappUrl, dappName, dappIcon, connectorIcon, key) {
            if (connectDappLoader.active) {
                connectionQueue.push({ dappChains, dappUrl, dappName, dappIcon, key, connectorIcon })
                return
            }

            connectDappLoader.dappChains = dappChains
            connectDappLoader.dappUrl = dappUrl
            connectDappLoader.dappName = dappName
            connectDappLoader.dappIcon = dappIcon
            connectDappLoader.connectorIcon = connectorIcon
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

        sourceComponent: ConnectDAppModal {
            visible: true

            onClosed: connectDappLoader.active = false
            accounts: root.accountsModel
            flatNetworks: SortFilterProxyModel {
                sourceModel: root.networksModel
                filters: [
                    FastExpressionFilter {
                        inverted: true
                        expression: connectDappLoader.dappChains.indexOf(chainId) === -1
                        expectedRoles: ["chainId"]
                    }
                ]
            }
            selectedAccountAddress: root.selectedAccountAddress

            dAppUrl: connectDappLoader.dappUrl
            dAppName: connectDappLoader.dappName
            dAppIconUrl: connectDappLoader.dappIcon
            dAppConnectorBadge: connectDappLoader.connectorIcon
            connectButtonEnabled: root.enabled

            onConnect: {
                if (!selectedAccount || !selectedAccount.address) {
                    console.error("Missing account selection")
                    return
                }
                if (!selectedChains || selectedChains.length === 0) {
                    console.error("Missing chain selection")
                    return
                }
                
                root.connectionAccepted(connectDappLoader.key, selectedChains, selectedAccount.address)
            }

            onDecline: {
                root.connectionDeclined(connectDappLoader.key)
                close()
            }

           onDisconnect: {
                root.disconnectRequested(connectDappLoader.topic, connectDappLoader.dappUrl, Constants.DAppConnectors.WalletConnect, "walletconnect")
                close()
            }
        }
    }

    Instantiator {
        model: root.sessionRequestsModel
        delegate: DAppSignRequestModal {
            id: dappRequestModal
            objectName: "dappsRequestModal"

            required property var model
            required property int index

            readonly property var request: model.requestItem
            readonly property var account: accountEntry.available ? accountEntry.item : {
                name: "",
                address: "",
                emoji: "",
                colorId: 0,
                migratedToKeycard: false
            }

            readonly property var network: networkEntry.available ? networkEntry.item : {
                chainName: "",
                iconUrl: ""
            }
            property bool requestHandled: false

            function rejectRequest() {
                // Allow rejecting only once
                if (requestHandled) {
                    return
                }
                requestHandled = true
                root.signRequestRejected(request.topic, request.requestId)
            }

            parent: root.visualParent

            loginType: account.migratedToKeycard ? Constants.LoginType.Keycard : root.loginType
            formatBigNumber: root.formatBigNumber

            visible: !!request.dappUrl

            dappUrl: request.dappUrl
            dappIcon: request.dappIcon
            dappName: request.dappName

            accountColor: Utils.getColorForId(Theme.palette, account.colorId)
            accountName: account.name
            accountAddress: account.address
            accountEmoji: account.emoji

            networkName: network.chainName
            networkIconPath: Assets.svg(network.iconUrl)

            fiatFees: request.fiatMaxFees ? request.fiatMaxFees.toFixed() : ""
            fiatSymbol: request.fiatSymbol
            cryptoFees: request.nativeTokenMaxFees ? request.nativeTokenMaxFees.toFixed() : ""
            nativeTokenSymbol: Utils.getNativeTokenSymbol(request.chainId)
            estimatedTime: WalletUtils.getLabelForEstimatedTxTime(request.estimatedTimeCategory)
            feesLoading: hasFees && (!fiatFees || !cryptoFees)
            estimatedTimeLoading: request.estimatedTimeCategory === Constants.TransactionEstimatedTime.Unknown
            hasFees: signingTransaction
            enoughFundsForTransaction: request.haveEnoughFunds
            enoughFundsForFees: request.haveEnoughFees

            signButtonEnabled: ((!hasFees) || enoughFundsForTransaction && enoughFundsForFees) && root.enabled
            signingTransaction: !!request.method && (request.method === SessionRequest.methods.signTransaction.name
                                                  || request.method === SessionRequest.methods.sendTransaction.name)
            requestPayload: {
                try {
                    const data = JSON.parse(request.preparedData)

                    delete data.maxFeePerGas
                    delete data.maxPriorityFeePerGas
                    delete data.gasPrice

                    return JSON.stringify(data, null, 2)
                } catch(_) {
                    return request.preparedData
                }
            }
            expirationSeconds: request.expirationTimestamp ? request.expirationTimestamp - requestTimestamp.getTime() / 1000
                                                            : 0
            hasExpiryDate: !!request.expirationTimestamp

            onOpened: {
                root.signRequestIsLive(request.topic, request.requestId)
            }

            onClosed: {
                Qt.callLater(rejectRequest)
            }

            onAccepted: {
                requestHandled = true
                root.signRequestAccepted(request.topic, request.requestId)
            }

            onRejected: {
                rejectRequest()
            }

            ModelEntry {
                id: accountEntry
                sourceModel: root.accountsModel
                key: "address"
                value: request.accountAddress
            }

            ModelEntry {
                id: networkEntry
                sourceModel: root.networksModel
                key: "chainId"
                value: request.chainId
            }
        }
    }

    Loader {
        id: dappConnectSelectLoader
        objectName: "dappConnectSelectLoader"
        active: false
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
            parent: root.visualParent

            title: qsTr("Connect a dApp")
            footer: StatusDialogFooter {
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
