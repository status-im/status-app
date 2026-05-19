import QtQuick
import QtTest

import AppLayouts.Browser.provider.qml

/**
 * Regression tests for per-tab ConnectorBridge (hub + OpenSea multi-tab).
 */
Item {
    id: root

    Component {
        id: mockConnectorControllerComponent

        QtObject {
            id: mock

            signal connected(string payload)
            signal disconnected(string payload)
            signal connectorCallRPCResult(int requestId, string payload)
            signal chainIdSwitched(string payload)
            signal accountChanged(string payload)

            property var rpcCalls: []

            function connectorCallRPC(requestId, json) {
                rpcCalls.push({ requestId: requestId, json: json, parsed: JSON.parse(json) })
            }

            function getDApps() { return "[]" }
            function disconnect() { return true }
            function changeAccount() {}
        }
    }

    Component {
        id: connectorBridgeComponent

        ConnectorBridge {
            required property var controller
            connectorController: controller
            tabUrl: "about:blank"
            tabIncognito: false
        }
    }

    Component {
        id: requestCompletedSpyComponent

        SignalSpy {
            required property var manager
            target: manager
            signalName: "requestCompletedEvent"
        }
    }

    TestCase {
        name: "ConnectorBridgeMultiTab"
        when: windowShown

        property var mock: null

        function init() {
            mock = createTemporaryObject(mockConnectorControllerComponent, root)
            mock.rpcCalls = []
        }

        function createBridge(tabUrl) {
            return createTemporaryObject(connectorBridgeComponent, root, {
                controller: mock,
                tabUrl: tabUrl,
                tabIncognito: false
            })
        }

        function createRequestCompletedSpy(manager) {
            return createTemporaryObject(requestCompletedSpyComponent, root, { manager: manager })
        }

        // Hub active, OpenSea in background: each tab must keep its own dapp origin in RPC.
        function test_concurrentTabsKeepIndependentDappOrigin() {
            const hubBridge = createBridge("https://hub.status.network/")
            const openseaBridge = createBridge("https://opensea.io/")

            compare(hubBridge.dappOrigin, "https://hub.status.network",
                    "Hub tab must expose hub origin without switching active tab")
            compare(openseaBridge.dappOrigin, "https://opensea.io",
                    "Background OpenSea tab must keep its own origin")

            hubBridge.connectorManager.request({ method: "eth_accounts", requestId: 101 })
            openseaBridge.connectorManager.request({ method: "eth_requestAccounts", requestId: 202 })

            compare(mock.rpcCalls.length, 2)
            compare(mock.rpcCalls[0].parsed.url, "https://hub.status.network")
            compare(mock.rpcCalls[1].parsed.url, "https://opensea.io")
        }

        // Connect on OpenSea must not flip connected state on an unrelated hub tab.
        function test_connectEventOnlyUpdatesMatchingTab() {
            const hubBridge = createBridge("https://hub.status.network/")
            const openseaBridge = createBridge("https://opensea.io/")
            const clientId = ConnectorConstants.clientIdFor(false)

            mock.connected(JSON.stringify({
                url: "https://opensea.io",
                clientId: clientId,
                sharedAccount: "0xabc",
                chainId: 1
            }))

            compare(openseaBridge.connectorManager.connected, true,
                    "OpenSea tab should become connected")
            compare(hubBridge.connectorManager.connected, false,
                    "Hub tab must not inherit OpenSea connection state")
            compare(openseaBridge.eip1193ProviderAdapter.accounts[0], "0xabc")
            compare(hubBridge.eip1193ProviderAdapter.accounts.length, 0)
        }

        // Shared Nim controller emits one RPC result; only the originating tab may forward it.
        function test_rpcResultOnlyReachesOriginatingBridge() {
            const hubBridge = createBridge("https://hub.status.network/")
            const openseaBridge = createBridge("https://opensea.io/")

            const hubCompletedSpy = createRequestCompletedSpy(hubBridge.connectorManager)
            const openseaCompletedSpy = createRequestCompletedSpy(openseaBridge.connectorManager)

            hubBridge.connectorManager.request({ method: "eth_chainId", requestId: 1 })
            openseaBridge.connectorManager.request({ method: "eth_accounts", requestId: 2 })

            mock.connectorCallRPCResult(2, JSON.stringify({
                jsonrpc: "2.0",
                id: 2,
                result: []
            }))

            compare(hubCompletedSpy.count, 0,
                    "Hub tab must ignore RPC results from other tabs")
            compare(openseaCompletedSpy.count, 1,
                    "OpenSea tab must receive its own RPC result")
        }
    }
}
