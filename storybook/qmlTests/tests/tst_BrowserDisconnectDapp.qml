import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.provider.qml
import AppLayouts.Browser.webview

import "../../../ui/app/AppLayouts/Browser/provider/qml/Utils.js" as Utils

/**
 * Regression: disconnecting a background dApp (OpenSea) while another tab (hub) is active.
 *
 * Bug (BrowserWebViewContext.disconnectDapp): uses currentWebView.bridge only, so Nim
 * disconnect is invoked from the wrong tab context and the matching tab stays connected.
 *
 * Fix: resolve the webview/bridge whose tab URL matches the dApp being disconnected.
 */
Item {
    id: root

    readonly property string hubUrl: "https://hub.status.network"
    readonly property string openseaUrl: "https://opensea.io"

    Component {
        id: mockConnectorControllerComponent

        QtObject {
            id: mock

            signal connected(string payload)
            signal disconnected(string payload)
            signal connectorCallRPCResult(int requestId, string payload)
            signal chainIdSwitched(string payload)
            signal accountChanged(string payload)

            property string lastDisconnectInvokerOrigin: ""
            property var disconnectCalls: []

            function connectorCallRPC(requestId, json) {
                connectorCallRPCResult(requestId, json)
            }

            function getDApps() { return "[]" }

            function disconnect(hostname, clientId) {
                const target = Utils.normalizeOrigin(hostname)
                const invoker = lastDisconnectInvokerOrigin
                const ok = invoker === target
                disconnectCalls.push({ target: target, invoker: invoker, ok: ok, clientId: clientId })
                lastDisconnectInvokerOrigin = ""
                return ok
            }

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
        id: bridgeDisconnectProxyComponent

        QtObject {
            required property var innerBridge
            required property var mockController

            readonly property string dappOrigin: innerBridge.dappOrigin
            readonly property var connectorManager: innerBridge.connectorManager
            readonly property var eip1193ProviderAdapter: innerBridge.eip1193ProviderAdapter

            function disconnect(hostname) {
                mockController.lastDisconnectInvokerOrigin = innerBridge.dappOrigin
                return innerBridge.disconnect(hostname)
            }
        }
    }

    Component {
        id: tabHostComponent

        Item {
            id: tabHost
            property url tabUrl
            property var bridge
        }
    }

    Component {
        id: tabsModelComponent

        QtObject {
            property int currentIndex: 0
            readonly property int count: 2
            function createEmptyTab() {}
            function createDownloadTab() {}
            function removeTab() {}
        }
    }

    Component {
        id: browserWebViewContextComponent

        BrowserWebViewContext {
            required property Item hostStack
            required property var tabsModelRef
            required property var connectorControllerRef

            thirdpartyServicesEnabled: true
            isDebugEnabled: false
            isMobile: true
            hasPopups: false
            browserSettings: QtObject {}
            connectorController: connectorControllerRef
            dappsEnabled: true
            hostStackLayout: hostStack
            tabsModel: tabsModelRef
            defaultProfileParams: ProfileParams {}
            bookmarksStore: QtObject {}
            downloadsStore: QtObject {}
            determineRealURLFn: function(url) { return url }
            downloadRequestHandler: function() {}
            sslErrorHandler: function() {}
            jsDialogHandler: function() {}
            findTextFinishedHandler: function() {}
        }
    }

    TestCase {
        name: "BrowserDisconnectDapp"
        when: windowShown

        property var mock: null
        property Item hostStack: null
        property var tabsModel: null
        property BrowserWebViewContext webViewContext: null
        property var hubBridgeProxy: null
        property var openseaBridgeProxy: null

        function init() {
            mock = createTemporaryObject(mockConnectorControllerComponent, root)
            mock.disconnectCalls = []

            hostStack = createTemporaryObject(tabHostComponent, root, { width: 1, height: 1 })
            tabsModel = createTemporaryObject(tabsModelComponent, root)

            const hubInner = createTemporaryObject(connectorBridgeComponent, root, {
                controller: mock,
                tabUrl: root.hubUrl,
                tabIncognito: false
            })
            const openseaInner = createTemporaryObject(connectorBridgeComponent, root, {
                controller: mock,
                tabUrl: root.openseaUrl,
                tabIncognito: false
            })

            hubBridgeProxy = createTemporaryObject(bridgeDisconnectProxyComponent, root, {
                innerBridge: hubInner,
                mockController: mock
            })
            openseaBridgeProxy = createTemporaryObject(bridgeDisconnectProxyComponent, root, {
                innerBridge: openseaInner,
                mockController: mock
            })

            createTemporaryObject(tabHostComponent, hostStack, {
                tabUrl: root.hubUrl,
                bridge: hubBridgeProxy
            })
            createTemporaryObject(tabHostComponent, hostStack, {
                tabUrl: root.openseaUrl,
                bridge: openseaBridgeProxy
            })

            webViewContext = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel,
                connectorControllerRef: mock
            })
        }

        function connectOpenSea() {
            const clientId = ConnectorConstants.clientIdFor(false)
            mock.connected(JSON.stringify({
                url: root.openseaUrl,
                clientId: clientId,
                sharedAccount: "0xda4a19b7aec958688d2531175e2757427372c6d1",
                chainId: 1
            }))
        }

        // Hub is the active tab; disconnect OpenSea from wallet must use OpenSea's bridge.
        function test_disconnectDappTargetsMatchingTabNotCurrentTab() {
            connectOpenSea()

            compare(openseaBridgeProxy.connectorManager.connected, true,
                    "OpenSea tab should be connected before disconnect")
            compare(hubBridgeProxy.connectorManager.connected, false,
                    "Hub tab must stay disconnected")

            tabsModel.currentIndex = 0
            compare(webViewContext.currentWebView.bridge.dappOrigin, root.hubUrl,
                    "Active tab must be hub while disconnecting background OpenSea")

            webViewContext.disconnectDapp(root.openseaUrl)

            compare(mock.disconnectCalls.length, 1, "disconnect must be invoked once")
            compare(mock.disconnectCalls[0].invoker, root.openseaUrl,
                    "disconnect must run through the OpenSea tab bridge, not the active hub tab")
            compare(mock.disconnectCalls[0].target, root.openseaUrl)
            verify(mock.disconnectCalls[0].ok,
                    "backend disconnect must succeed when invoked from the matching tab bridge")

            mock.disconnected(JSON.stringify({
                url: root.openseaUrl,
                clientId: ConnectorConstants.clientIdFor(false)
            }))

            compare(openseaBridgeProxy.connectorManager.connected, false,
                    "OpenSea provider state must clear after disconnect")
            compare(hubBridgeProxy.connectorManager.connected, false,
                    "Hub tab must remain disconnected")
        }
    }
}
