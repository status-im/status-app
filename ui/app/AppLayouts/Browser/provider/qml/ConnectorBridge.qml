import QtQuick
import QtWebChannel

import AppLayouts.Browser.adapters

import "Utils.js" as BrowserUtils

/**
 * ConnectorBridge
 *
 * Simplified connector infrastructure for BrowserLayout.
 * Provides WebChannel, ConnectorManager, and direct connection to Nim backend.
 *
 * This component bridges the Browser UI with the Connector backend system.
 */
QtObject {
    id: root

    required property string userUID
    property bool featureEnabled: true
    required property var connectorController
    property string httpUserAgent: ""          // Custom user agent for web profiles

    readonly property ProfileParams defaultProfileParams: ProfileParams {
        userId: root.userUID
        userAgent: root.httpUserAgent
        scripts: root.scriptPaths
        offTheRecord: false
    }

    readonly property ProfileParams otrProfileParams: ProfileParams {
        userId: root.userUID
        userAgent: root.httpUserAgent
        scripts: root.scriptPaths
        offTheRecord: true
    }

    readonly property var scriptPaths: root.featureEnabled ? [
        { path: Qt.resolvedUrl("../js/qwebchannel.js"), runOnSubFrames: true },
        { path: Qt.resolvedUrl("../js/ethereum_wrapper.js"), runOnSubFrames: true },
        { path: Qt.resolvedUrl("../js/eip6963_announcer.js"), runOnSubFrames: false },
        { path: Qt.resolvedUrl("../js/ethereum_injector.js"), runOnSubFrames: true }
    ] : []

    readonly property alias dappUrl: connectorManager.dappUrl
    readonly property alias dappOrigin: connectorManager.dappOrigin
    readonly property alias dappName: connectorManager.dappName
    readonly property alias dappIconUrl: connectorManager.dappIconUrl
    readonly property alias clientId: connectorManager.clientId

    readonly property ConnectorManager connectorManager: ConnectorManager {
        id: connectorManager
        connectorController: root.connectorController  // (shared_modules/connector/controller.nim)

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

    function hasWalletConnected(hostname, address) {
        if (!connectorController) return false

        const dApps = connectorController.getDApps()
        try {
            const dAppsObj = JSON.parse(dApps)
            if (Array.isArray(dAppsObj)) {
                return dAppsObj.some(function(dapp) {
                    return dapp.url && dapp.url.indexOf(hostname) >= 0
                })
            }
        } catch (e) {
            console.warn("[ConnectorBridge] Error checking wallet connection:", e)
        }
        return false
    }

    function disconnect(hostname) {
        if (!connectorController) {
            return false
        }

        const result = connectorController.disconnect(hostname, clientId)
        return result
    }

    function disconnectCurrentTab() {
        if (!dappOrigin) {
            return false
        }

        return disconnect(dappOrigin)
    }

    function updateDAppUrl(url, name) {
        connectorManager.updateDAppUrl(url, name)
    }
}
