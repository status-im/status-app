import QtQuick

import SortFilterProxyModel
import StatusQ

import AppLayouts.Browser.provider.qml
import shared.popups.walletconnect
import utils

ConnectDAppModal {
    id: root

    // chain ids the dApp asks for
    required property var dappChains
    required property var networksModel
    required property var key
    required property int dappConnectorId
    property var topic

    property bool connectRequestHandled: false

    signal connectionAccepted(var key, var chainIds, string selectedAccount)
    signal connectionDeclined(var key)
    signal disconnectRequested(string topic, string url, int connectorId, string clientId)

    function resolve(action) {
        root.connectRequestHandled = true
        action()
    }

    Component.onCompleted: {
        console.log("[StatusConnect] ConnectDAppModal shown",
                     "url=" + root.dAppUrl,
                     "key=" + root.key)
    }

    onClosed: {
        if (!root.connectRequestHandled && root.key)
            root.connectionDeclined(root.key)
    }

    flatNetworks: SortFilterProxyModel {
        sourceModel: root.networksModel
        filters: [
            FastExpressionFilter {
                inverted: true
                expression: root.dappChains.indexOf(chainId) === -1
                expectedRoles: ["chainId"]
            }
        ]
    }

    onConnect: {
        if (!selectedAccount || !selectedAccount.address) {
            console.error("Missing account selection")
            return
        }
        if (!selectedChains || selectedChains.length === 0) {
            console.error("Missing chain selection")
            return
        }

        root.resolve(() => root.connectionAccepted(root.key, selectedChains, selectedAccount.address))
    }

    onDecline: root.resolve(() => {
        root.connectionDeclined(root.key)
        root.close()
    })

    onDisconnect: root.resolve(() => {
        const connectorId = root.dappConnectorId
        const isStatusConnect = connectorId === Constants.DAppConnectors.StatusConnect
        const clientId = isStatusConnect
                ? ConnectorConstants.clientIdFor(false)
                : "walletconnect"
        const topic = root.topic || root.dAppUrl
        console.log("[StatusConnect] ConnectDAppModal disconnect",
                     "url=" + root.dAppUrl,
                     "connectorId=" + connectorId,
                     "clientId=" + clientId)
        root.disconnectRequested(topic, root.dAppUrl, connectorId, clientId)
        root.close()
    })
}
