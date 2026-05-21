import QtQuick
import QtWebChannel

import "Utils.js" as BrowserUtils

/**
 * ConnectorBridge
 *
 * Per-tab connector infrastructure.
 * Provides WebChannel, ConnectorManager, and direct connection to Nim backend.
 */
QtObject {
    id: root

    required property var connectorController

    required property url tabUrl
    required property bool tabIncognito
    property string tabTitle: ""
    property url tabIconUrl: ""

    readonly property alias dappUrl: connectorManager.dappUrl
    readonly property alias dappOrigin: connectorManager.dappOrigin
    readonly property alias dappName: connectorManager.dappName
    readonly property alias dappIconUrl: connectorManager.dappIconUrl
    readonly property alias clientId: connectorManager.clientId

    readonly property ConnectorManager connectorManager: ConnectorManager {
        id: connectorManager
        connectorController: root.connectorController  // (shared_modules/connector/controller.nim)
        offTheRecord: root.tabIncognito

        // Forward events to Eip1193ProviderAdapter
        onConnectEvent: (info) => eip1193ProviderAdapter.connectEvent(info)
        onAccountsChangedEvent: (accounts) => eip1193ProviderAdapter.accountsChangedEvent(accounts)
        onChainChangedEvent: (chainId) => eip1193ProviderAdapter.chainChangedEvent(chainId)
        onRequestCompletedEvent: (payload) => eip1193ProviderAdapter.requestCompletedEvent(payload)
        onDisconnectEvent: (error) => eip1193ProviderAdapter.disconnectEvent(error)
        onMessageEvent: (message) => eip1193ProviderAdapter.messageEvent(message)
        onProviderStateChanged: () => eip1193ProviderAdapter.providerStateChanged()
    }

    readonly property Eip1193ProviderAdapter eip1193ProviderAdapter: Eip1193ProviderAdapter {
        id: eip1193Provider
        objectName: "ethereumProvider"
        WebChannel.id: "ethereumProvider"

        chainId: BrowserUtils.chainIdToHex(connectorManager.dappChainId)
        networkVersion: connectorManager.dappChainId.toString()
        selectedAddress: connectorManager.accounts.length > 0 ? connectorManager.accounts[0] : ""
        accounts: connectorManager.accounts
        connected: connectorManager.connected

        onRequestInternal: (args) => connectorManager.request(args)
    }

    readonly property WebChannel channel: WebChannel {
        registeredObjects: [eip1193ProviderAdapter]
    }

    function syncTabMetadata() {
        if (!tabUrl || !tabUrl.toString())
            return
        connectorManager.updateDAppUrl(tabUrl, tabTitle, tabIconUrl)
    }

    onTabUrlChanged: syncTabMetadata()
    onTabTitleChanged: syncTabMetadata()
    onTabIconUrlChanged: syncTabMetadata()
    onTabIncognitoChanged: syncTabMetadata()

    Component.onCompleted: syncTabMetadata()

    function disconnect(hostname) {
        if (!connectorController) {
            return false
        }

        return connectorController.disconnect(hostname, clientId)
    }
}
