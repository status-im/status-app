import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.provider.qml
import AppLayouts.Browser.webview

import "../../../ui/app/AppLayouts/Browser/provider/qml/Utils.js" as Utils

/**
 * Regression: BrowserWebViewContext.disconnectDapp for browser dApp combobox.
 * Disconnect goes through connectorController using currentClientId (browser profile).
 */
Item {
    id: root

    readonly property string hubUrl: "https://hub.status.network"
    readonly property string openseaUrl: "https://opensea.io"
    readonly property string browserClientId: ConnectorConstants.clientIdFor(false)

    Component {
        id: mockConnectorControllerComponent

        QtObject {
            id: mock

            signal connected(string payload)
            signal disconnected(string payload)
            signal connectorCallRPCResult(int requestId, string payload)
            signal chainIdSwitched(string payload)
            signal accountChanged(string payload)

            property var disconnectCalls: []

            function connectorCallRPC(requestId, json) {
                connectorCallRPCResult(requestId, json)
            }

            function getDApps() { return "[]" }

            function disconnect(hostname, clientId) {
                const target = Utils.normalizeOrigin(hostname)
                disconnectCalls.push({ target: target, clientId: clientId })
                return true
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
        id: tabHostComponent

        Item {
            id: tabHost
            property url url
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
        id: tabsModelSingleTabComponent

        QtObject {
            property int currentIndex: 0
            readonly property int count: 1
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
            defaultProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: false
            }
            otrProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: true
            }
            bookmarksStore: QtObject {}
            downloadsStore: QtObject {}
            determineRealURLFn: function(url) { return url }
            downloadRequestHandler: function() {}
            sslErrorHandler: function() {}
            jsDialogHandler: function() {}
            findTextFinishedHandler: function() {}
            savedSessionContext: QtObject {
                function seedWebView() {}
            }
        }
    }

    TestCase {
        name: "BrowserDisconnectDapp"
        when: windowShown

        property var mock: null
        property Item hostStack: null
        property var tabsModel: null
        property BrowserWebViewContext webViewContext: null
        property var hubBridge: null
        property var openseaBridge: null

        function init() {
            mock = createTemporaryObject(mockConnectorControllerComponent, root)
            mock.disconnectCalls = []

            hostStack = createTemporaryObject(tabHostComponent, root, { width: 1, height: 1 })
            tabsModel = createTemporaryObject(tabsModelComponent, root)

            hubBridge = createTemporaryObject(connectorBridgeComponent, root, {
                controller: mock,
                tabUrl: root.hubUrl,
                tabIncognito: false
            })
            openseaBridge = createTemporaryObject(connectorBridgeComponent, root, {
                controller: mock,
                tabUrl: root.openseaUrl,
                tabIncognito: false
            })

            createTemporaryObject(tabHostComponent, hostStack, {
                url: root.hubUrl,
                bridge: hubBridge
            })
            createTemporaryObject(tabHostComponent, hostStack, {
                url: root.openseaUrl,
                bridge: openseaBridge
            })

            webViewContext = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel,
                connectorControllerRef: mock
            })
        }

        function connectOpenSea() {
            mock.connected(JSON.stringify({
                url: root.openseaUrl,
                clientId: root.browserClientId,
                sharedAccount: "0xda4a19b7aec958688d2531175e2757427372c6d1",
                chainId: 1
            }))
        }

        // Hub is active; disconnect OpenSea from combobox must not use the hub tab bridge.
        function test_disconnectDappUsesControllerNotActiveTabBridge() {
            connectOpenSea()

            compare(openseaBridge.connectorManager.connected, true,
                    "OpenSea tab should be connected before disconnect")
            compare(hubBridge.connectorManager.connected, false,
                    "Hub tab must stay disconnected")

            tabsModel.currentIndex = 0
            compare(webViewContext.currentWebView.bridge.dappOrigin, root.hubUrl,
                    "Active tab must be hub while disconnecting background OpenSea")

            verify(webViewContext.disconnectDapp(root.openseaUrl))

            compare(mock.disconnectCalls.length, 1, "disconnect must be invoked once")
            compare(mock.disconnectCalls[0].target, root.openseaUrl)
            compare(mock.disconnectCalls[0].clientId, root.browserClientId)

            mock.disconnected(JSON.stringify({
                url: root.openseaUrl,
                clientId: root.browserClientId
            }))

            compare(openseaBridge.connectorManager.connected, false,
                    "OpenSea provider state must clear after disconnect")
            compare(hubBridge.connectorManager.connected, false,
                    "Hub tab must remain disconnected")
        }

        // OpenSea tab closed; clientId comes from the active tab profile (currentClientId).
        function test_disconnectDappUsesCurrentProfileClientIdWhenTabClosed() {
            const localMock = createTemporaryObject(mockConnectorControllerComponent, root)
            localMock.disconnectCalls = []

            const localHostStack = createTemporaryObject(tabHostComponent, root, { width: 1, height: 1 })
            const localTabsModel = createTemporaryObject(tabsModelSingleTabComponent, root)

            const hubBridgeLocal = createTemporaryObject(connectorBridgeComponent, root, {
                controller: localMock,
                tabUrl: root.hubUrl,
                tabIncognito: false
            })

            createTemporaryObject(tabHostComponent, localHostStack, {
                url: root.hubUrl,
                bridge: hubBridgeLocal
            })

            const localWebViewContext = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: localHostStack,
                tabsModelRef: localTabsModel,
                connectorControllerRef: localMock
            })

            compare(localTabsModel.count, 1, "OpenSea tab must be closed")
            compare(localWebViewContext.currentWebView.url, root.hubUrl,
                    "Only hub tab is open while disconnecting OpenSea from combobox")

            verify(localWebViewContext.disconnectDapp(root.openseaUrl),
                   "disconnect from browser dApp combobox must succeed without a matching tab")
            compare(localMock.disconnectCalls.length, 1,
                    "controller.disconnect must be invoked when no tab matches the dApp URL")
            compare(localMock.disconnectCalls[0].target, root.openseaUrl)
            compare(localMock.disconnectCalls[0].clientId, root.browserClientId)
        }
    }
}
