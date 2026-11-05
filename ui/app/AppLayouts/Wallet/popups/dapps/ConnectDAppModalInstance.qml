import QtQuick

import SortFilterProxyModel
import QtModelsToolkit
import StatusQ

import AppLayouts.Browser.provider.qml
import shared.popups.walletconnect
import utils

ConnectDAppModal {
    required property var workflow
    required property var loader

    visible: true

    Component.onCompleted: {
        console.log("[StatusConnect] ConnectDAppModal shown",
                     "url=" + loader.dappUrl,
                     "key=" + loader.key)
    }

    onClosed: {
        if (!loader.connectRequestHandled && loader.key) {
            workflow.connectionDeclined(loader.key)
        }
        loader.connectRequestHandled = false
        loader.active = false
    }
    accounts: workflow.accountsModel
    flatNetworks: SortFilterProxyModel {
        sourceModel: workflow.networksModel
        filters: [
            FastExpressionFilter {
                inverted: true
                expression: loader.dappChains.indexOf(chainId) === -1
                expectedRoles: ["chainId"]
            }
        ]
    }
    selectedAccountAddress: workflow.selectedAccountAddress

    dAppUrl: loader.dappUrl
    dAppName: loader.dappName
    dAppIconUrl: loader.dappIcon
    dAppConnectorBadge: loader.connectorIcon
    connectButtonEnabled: workflow.enabled

    onConnect: {
        if (!selectedAccount || !selectedAccount.address) {
            console.error("Missing account selection")
            return
        }
        if (!selectedChains || selectedChains.length === 0) {
            console.error("Missing chain selection")
            return
        }

        loader.resolve(() => workflow.connectionAccepted(loader.key, selectedChains, selectedAccount.address))
    }

    onDecline: loader.resolve(() => {
        workflow.connectionDeclined(loader.key)
        close()
    })

    onDisconnect: loader.resolve(() => {
        const connectorId = loader.dappConnectorId
        const isStatusConnect = connectorId === Constants.DAppConnectors.StatusConnect
        const clientId = isStatusConnect
                ? ConnectorConstants.clientIdFor(false)
                : "walletconnect"
        const topic = loader.topic || loader.dappUrl
        console.log("[StatusConnect] ConnectDAppModal disconnect",
                     "url=" + loader.dappUrl,
                     "connectorId=" + connectorId,
                     "clientId=" + clientId)
        workflow.disconnectRequested(topic, loader.dappUrl, connectorId, clientId)
        close()
    })
}
