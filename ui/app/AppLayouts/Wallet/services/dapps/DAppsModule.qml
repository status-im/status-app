import QtQuick

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.plugins
import AppLayouts.Wallet.services.dapps.types
import AppLayouts.Wallet.stores as WalletStore

import StatusQ.Core.Utils as SQUtils

import shared.stores
import utils

import "./internal"

/// Component that provides the dapps integration for the wallet.
/// It provides the following features:
/// - WalletConnect integration
///     - WalletConnect pairing
///     - WalletConnect sessions management
///     - WalletConnect signing requests
///     - WalletConnect SIWE
///     - WalletConnect online status
/// - BrowserConnect integration
///     - BrowserConnect pairing
///     - BrowserConnect - access to persistent sessions
///     - BrowserConnect - access to persistent signing requests
///     - BrowserConnect signing requests
///     - BrowserConnect online status
SQUtils.QObject {
    id: root

    // SDKs providing the DApps API
    required property WalletConnectSDKBase wcSdk
    required property WalletConnectSDKBase bcSdk

    // DApps shared store - used for wc peristence and signing requests/transactions
    required property DAppsStore store
    required property CurrenciesStore currenciesStore

    // Required roles: address
    required property var accountsModel
    // Required roles: chainId, layer, isOnline
    required property var networksModel
    // Required roles: tokenKey, balances
    required property var groupedAccountAssetsModel

    readonly property alias requestsModel: requests
    readonly property alias dappsModel: dappConnections.dappsModel
    readonly property bool enabled: wcSdk.enabled || bcSdk.enabled
    readonly property bool isServiceOnline: chainsSupervisorPlugin.isOnline && (wcSdk.sdkReady || bcSdk.enabled)

    // Connection signals
    /// Emitted when a new DApp requests a connection
    signal connectDApp(var chains, string dAppUrl, string dAppName, string dAppIcon, int connectorId, string key)
    /// Emitted when a new DApp is connected
    signal dappConnected(string proposalId, string newTopic, string url, int connectorId)
    /// Emitted when a DApp is disconnected
    signal dappDisconnected(string url)
    /// Emitted when a new DApp fails to connect
    signal newConnectionFailed(string key, string dappUrl, var error)

    // Pairing signals
    signal pairingValidated(int validationState)
    signal pairingResponse(int state) // Maps to Pairing.errors

    // Sign request signals
    signal signCompleted(string topic, string id, bool userAccepted, string error)
    signal siweCompleted(string topic, string id, string error)

    /// WalletConnect pairing
    /// @param uri - the pairing URI to pair
    /// Result is emitted via the pairingResponse signal
    /// A new session proposal is expected to be emitted if the pairing is successful
    function pair(uri) {
        return wcSdk.pair(uri)
    }

    /// Approves or rejects the session proposal. App response to `connectDApp`
    /// @param key - the key of the session proposal
    /// @param approvedChainIds - array containing the chainIds that the user approved
    /// @param accountAddress - the address of the account that approved the session
    function approvePairSession(key, approvedChainIds, accountAddress) {
        if (siwePlugin.connectionRequests.has(key.toString())) {
            siwePlugin.accept(key, approvedChainIds, accountAddress)
            siwePlugin.connectionRequests.delete(key.toString())
            return
        }
        dappConnections.accept(key, approvedChainIds, accountAddress)
    }

    /// Rejects the session proposal. App response to `connectDApp`
    /// @param id - the id of the session proposal
    function rejectPairSession(id) {
        if (siwePlugin.connectionRequests.has(id.toString())) {
            siwePlugin.reject(id)
            siwePlugin.connectionRequests.delete(id.toString())
            return
        }
        dappConnections.reject(id)
    }

    /// Disconnects the dApp with the given topic/URL. Expected `dappDisconnected` signal
    /// @param topic - the topic (for WC) or URL (for BC) of the dApp to disconnect
    /// @param url - the URL of the dApp
    /// @param connectorId - the connector type (Constants.DAppConnectors.WalletConnect or Constants.DAppConnectors.StatusConnect)
    /// @param clientId - the clientId for BC sessions (e.g. "status-desktop/dapp-browser" for browser connections)
    function disconnect(topic, url, connectorId, clientId) {
        if (connectorId === Constants.DAppConnectors.WalletConnect) {
            wcSdk.disconnectByTopic(topic, url)
        } else {
            bcSdk.disconnect(url, clientId || "")
        }
    }

    /// Validates the pairing URI and emits the pairingValidated signal. Expected `pairingValidated` signal
    /// Async function
    /// @param uri - the pairing URI to validate
    function validatePairingUri(uri){
        const info = DAppsHelpers.extractInfoFromPairUri(uri)
        wcSdk.getActiveSessions((sessions) => {
            // Check if the URI is already paired
            let validationState = Pairing.errors.uriOk
            for (const key in sessions) {
                if (sessions[key].pairingTopic === info.topic) {
                    validationState = Pairing.errors.alreadyUsed
                    break
                }
            }

            // Check if expired
            if (validationState === Pairing.errors.uriOk) {
                const now = (new Date().getTime())/1000
                if (info.expiry < now) {
                    validationState = Pairing.errors.expired
                }
            }

            root.pairingValidated(validationState)
        });
    }

    DAppConnectionsPlugin {
        id: dappConnections
        wcSDK: root.wcSdk
        bcSDK: root.bcSdk
        dappsStore: root.store
        accountsModel: root.accountsModel
        networksModel: root.networksModel

        onConnected: (proposalId, topic, url, connectorId) => {
            root.dappConnected(proposalId, topic, url, connectorId)
        }
        onDisconnected: (url, connectorId) => {
            root.dappDisconnected(url)
        }
        onNewConnectionProposed: (key, chains, dAppUrl, dAppName, dAppIcon, connectorId) => {
            root.connectDApp(chains, dAppUrl, dAppName, dAppIcon, connectorId, key)
        }
        onNewConnectionFailed: (key, dappUrl, error) => {
            root.newConnectionFailed(key, dappUrl, error)
        }

        function accept(key, approvedChainIds, accountAddress) {
            const dappUrl = dappConnections.getDAppUrl(key)
            const connectorId = dappConnections.getConnectorId(key)
            dappConnections.connect(key, approvedChainIds, accountAddress)
        }

        function reject(key) {
            const dappUrl = dappConnections.getDAppUrl(key)
            const connectorId = dappConnections.getConnectorId(key)
            dappConnections.reject(key)
        }
    }

    SessionRequestsModel {
        id: requests
    }

    ChainsSupervisorPlugin {
        id: chainsSupervisorPlugin

        sdk: root.wcSdk
        networksModel: root.networksModel
        onAllChainsOfflineChanged: {
            if (!allChainsOffline) {
                return
            }
        }

        onNetworkOfflineChanged: {
            if (!networkOffline) {
                return
            }
        }
    }

    Connections {
        target: root.wcSdk
        enabled: root.wcSdk.enabled

        function onPairResponse(ok, error) {
            // pairingResponse expects Pairing.errors int: uriOk (1) on success, not a boolean
            root.pairingResponse(ok ? Pairing.errors.uriOk : Pairing.errors.unknownError)
        }

        function onSdkInit(success, result) {
            if (!success) {
                return
            }
        }
    }

    SiweRequestPlugin {
        id: siwePlugin

        readonly property var connectionRequests: new Map()
        sdk: root.wcSdk
        store: root.store
        accountsModel: root.accountsModel
        networksModel: root.networksModel

        onRegisterSignRequest: (request) => {
            requests.enqueue(request)
        }

        onUnregisterSignRequest: (requestId) => {
            const request = requests.findById(requestId)
            if (request === null) {
                console.error("SiweRequestPlugin::onUnregisterSignRequest: Error finding event for requestId", requestId)
                return
            }
            requests.removeRequest(request.topic, requestId)
        }

        onConnectDApp: (chains, dAppUrl, dAppName, dAppIcon, key) => {
            siwePlugin.connectionRequests.set(key.toString(), {chains, dAppUrl, dAppName, dAppIcon})
            root.connectDApp(chains, dAppUrl, dAppName, dAppIcon, Constants.DAppConnectors.WalletConnect, key)
        }

        onSiweFailed: (id, error, topic) => {
            root.siweCompleted(topic, id, error)
        }

        onSiweSuccessful: (id, topic) => {
            d.lookupSession(topic, function(session) {
                // Session already persisted by connector when SIWE auth was approved
                root.siweCompleted(topic, id, "")
            })
        }

        function accept(key, approvedChainIds, accountAddress) {
            const approvedNamespaces = JSON.parse(
                DAppsHelpers.buildSupportedNamespaces(approvedChainIds,
                                                [accountAddress],
                                                SessionRequest.getSupportedMethods()))
            const dappUrl = siwePlugin.getDAppUrl(key)
            siwePlugin.connectionApproved(key, approvedNamespaces)
        }

        function reject(key) {
            const dappUrl = siwePlugin.getDAppUrl(key)
            siwePlugin.connectionRejected(key)
        }
    }

    SQUtils.QObject {
        id: d

        function lookupSession(topicToLookup, callback) {
            wcSdk.getActiveSessions((res) => {
                Object.keys(res).forEach((topic) => {
                    if (topic === topicToLookup) {
                        let session = res[topic]
                        callback(session)
                    }
                })
            })
        }
    }

    // The fees broker to handle all fees requests for all components and connections
    TransactionFeesBroker {
        id: feesBroker
        store: root.store
    }

    // bcSignRequestPlugin and wcSignRequestPlugin are used to handle sign requests
    // Almost identical, and it's worth extracting in an inline component, but Qt5.15.2 doesn't support it
    SignRequestPlugin {
        id: bcSignRequestPlugin

        sdk: root.bcSdk
        groupedAccountAssetsModel: root.groupedAccountAssetsModel
        networksModel: root.networksModel
        accountsModel: root.accountsModel
        store: root.store
        requests: root.requestsModel
        dappsModel: root.dappsModel
        feesBroker: feesBroker

        fiatSymbol: root.currenciesStore.currentCurrency
        getFiatValue: (value, tokenKey) => {
            return root.currenciesStore.getFiatValue(value, tokenKey)
        }

        onAccepted: (topic, id, userAccepted) => {
            const request = root.requestsModel.findRequest(topic, id)
            if (!request) {
                return
            }
        }

        onRejected: (topic, id, hasError) => {
            if (hasError) {
                return
            }
            const request = root.requestsModel.findRequest(topic, id)
            if (!request) {
                return
            }
        }

        onSignCompleted: (topic, id, userAccepted, error) => {
            root.signCompleted(topic, id, userAccepted, error)
        }
    }

    SignRequestPlugin {
        id: wcSignRequestPlugin

        sdk: root.wcSdk
        groupedAccountAssetsModel: root.groupedAccountAssetsModel
        networksModel: root.networksModel
        accountsModel: root.accountsModel
        store: root.store
        requests: root.requestsModel
        dappsModel: root.dappsModel
        feesBroker: feesBroker

        fiatSymbol: root.currenciesStore.currentCurrency
        getFiatValue: (value, tokenKey) => {
            return root.currenciesStore.getFiatValue(value, tokenKey)
        }

        onAccepted: (topic, id, userAccepted) => {
            const request = root.requestsModel.findRequest(topic, id)
            if (!request) {
                return
            }
        }

        onRejected: (topic, id, hasError) => {
            if (hasError) {
                return
            }
            const request = root.requestsModel.findRequest(topic, id)
            if (!request) {
                return
            }
        }

        onSignCompleted: (topic, id, userAccepted, error) => {
            root.signCompleted(topic, id, userAccepted, error)
        }
    }
}
