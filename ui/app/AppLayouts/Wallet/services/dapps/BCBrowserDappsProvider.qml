import QtQuick

import AppLayouts.Wallet.services.dapps
import StatusQ.Core.Utils

import shared.stores
import utils

DAppsModel {
    id: root
    
    required property var connectorController
    property var clientIdFilter: null
    
    readonly property int connectorId: Constants.StatusConnect
    property string clientId: ""
    readonly property bool enabled: !!connectorController
    
    signal connected(string dappUrl)
    signal disconnected(string dappUrl)
    
    Connections {
        target: root.connectorController
        enabled: root.enabled
        
        function onConnected(payload) {
            d.handleSignal(payload, "connected")
        }
        
        function onDisconnected(payload) {
            d.handleSignal(payload, "disconnected")
        }
        
        function onAccountChanged(payload) {
            d.handleSignal(payload, "accountChanged")
        }
    }
    
    QtObject {
        id: d
        
        function handleSignal(payload, signalName) {
            try {
                const data = JSON.parse(payload)
                if (root.clientIdFilter !== null && data.clientId !== root.clientIdFilter) {
                    return
                }
                
                d.refreshModel()
            } catch (error) {
                console.error("[BCBrowserDappsProvider] Error processing", signalName, "signal:", error)
            }
        }
        
        function getConnectorBadge(connectorId) {
            const dappImageByType = [
                "status-logo",
                "network/Network=WalletConnect",
                "status-logo"
            ]
            return dappImageByType[connectorId] || ""
        }
        
        function refreshModel() {
            if (!root.connectorController) {
                return
            }
            
            root.clear()
            
            let dAppsJson
            if (root.clientIdFilter === null) {
                dAppsJson = root.connectorController.getDApps()
            } else {
                dAppsJson = root.connectorController.getDAppsByClientId(root.clientIdFilter)
            }
            
            const dApps = JSON.parse(dAppsJson)

            for (let i = 0; i < dApps.length; i++) {
                const dapp = dApps[i]
                const badge = d.getConnectorBadge(root.connectorId)

                const dappEntry = {
                    url: dapp.url,
                    name: dapp.name,
                    iconUrl: dapp.iconUrl || "",
                    topic: dapp.url,
                    connectorId: root.connectorId,
                    connectorBadge: badge,
                    clientId: root.clientId,
                    accountAddresses: dapp.sharedAccount ? [{address: dapp.sharedAccount}] : [],
                    rawSessions: []
                }
                root.append(dappEntry)
            }
        }
    }
    
    Component.onCompleted: {
        d.refreshModel()
    }
}

