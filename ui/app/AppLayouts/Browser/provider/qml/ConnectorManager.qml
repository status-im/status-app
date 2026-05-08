import QtQuick
import "Utils.js" as Utils

QtObject {
    id: root

    property var connectorController: null

    // dApp metadata
    property string dappUrl: ""
    property string dappOrigin: ""
    property string dappName: ""
    property string dappIconUrl: ""
    property int dappChainId: 1
    property bool offTheRecord: false
    readonly property string clientId: ConnectorConstants.clientIdFor(offTheRecord)

    // STATE
    property bool connected: false
    property var accounts: []
    property bool _initialConnectionDone: false

    // SIGNALS
    // Notify to re-read all properties
    signal providerStateChanged()

    // events for Eip1193ProviderAdapter
    signal connectEvent(var info)
    signal disconnectEvent(var error)
    signal accountsChangedEvent(var accounts)
    signal chainChangedEvent(string chainId)
    signal messageEvent(var message)
    signal requestCompletedEvent(var payload)

    // PUBLIC API - EIP-1193 REQUEST
    function request(args) {
        if (!args || !args.method) {
            console.error("[ConnectorManager] Invalid request - missing method")
            return JSON.stringify({
                error: { code: -32600, message: "Missing method" }  // EIP-1193: Invalid Request
            })
        }

        const method = args.method
        const requestId = args.requestId || 0

        var rpcRequest = {
            "jsonrpc": "2.0",
            "id": requestId,
            "method": method,
            "params": args.params || [],
            "url": dappOrigin || "",
            "name": dappName || "Unknown dApp",
            "clientId": clientId,
            "chainId": dappChainId,
            "iconUrl": dappIconUrl || ""
        }

        // Direct call to Nim connectorCallRPC -> status-go connector/api.go
        if (!connectorController) {
            console.error("[ConnectorManager] connectorController not available")
            return JSON.stringify({
                jsonrpc: "2.0",
                id: requestId,
                error: { code: -32603, message: "Internal error: connector not available" }
            })
        }

        connectorController.connectorCallRPC(requestId, JSON.stringify(rpcRequest))

        // Return immediately - response comes via connectorCallRPCResult signal
        return JSON.stringify({
            jsonrpc: "2.0",
            id: requestId,
            result: null
        })
    }

    // STATE MANAGEMENT METHODS
    function updateAccounts(newAccounts) {
        if (!Utils.accountsDidChange(accounts, newAccounts)) {
            return false
        }

        accounts = newAccounts

        providerStateChanged()
        accountsChangedEvent(accounts)
        return true
    }

    function setConnected(isConnected) {
        if (connected === isConnected) {
            return false
        }

        connected = isConnected

        if (connected && !_initialConnectionDone) {
            _initialConnectionDone = true
            const chainIdHex = Utils.chainIdToHex(dappChainId)

            providerStateChanged()
            connectEvent({ chainId: chainIdHex })
            console.log("[ConnectorManager] Initial connection established")
        } else {
            providerStateChanged()
        }

        return true
    }

    function clearState() {
        if (accounts.length === 0 && !connected) {
            return false
        }

        accounts = []
        connected = false
        _initialConnectionDone = false

        providerStateChanged()
        disconnectEvent({ code: 4900, message: "User disconnected" })  // EIP-1193: Disconnected
        accountsChangedEvent([])
        return true
    }

    // PUBLIC API
    function disconnect() {
        clearState()

        if (connectorController) {
            connectorController.disconnect(dappOrigin, clientId)
        }
    }

    function changeAccount(newAccount) {
        if (connectorController) {
            connectorController.disconnect(dappOrigin, clientId)
            connectorController.changeAccount(dappOrigin, clientId, newAccount)
        }
    }

    function updateDAppUrl(url, name, iconUrl) {
        if (!url) return

        const urlStr = url.toString()
        dappUrl = urlStr
        dappOrigin = Utils.normalizeOrigin(urlStr)
        dappName = name || Utils.extractDomainName(urlStr)
        dappIconUrl = Utils.normalizeFaviconUrl(iconUrl ? iconUrl.toString() : "")
        dappChainId = 1
    }

    // HELPER FUNCTIONS
    function shouldProcessSignal(event) {
        // Filter by origin
        if (event.url && Utils.normalizeOrigin(event.url) !== Utils.normalizeOrigin(dappOrigin)) {
            console.log("[ConnectorManager] Ignoring signal for other origin:", event.url, "expected:", dappOrigin)
            return false
        }
        // Filter by clientId
        if (event.clientId !== undefined && event.clientId !== "" && clientId !== "" && event.clientId !== clientId) {
            console.log("[ConnectorManager] Ignoring signal for other clientId:", event.clientId, "expected:", clientId)
            return false
        }

        return true
    }

    // SIGNAL HANDLERS
    readonly property Connections _connections: Connections {
        target: connectorController

        function onConnected(payload) {
            try {
                const data = JSON.parse(payload)

                if (!shouldProcessSignal(data)) return

                const newAccounts = data.sharedAccount ? [data.sharedAccount] : []
                updateAccounts(newAccounts)

                if (data.chainId) {
                    const newChainId = data.chainId
                    if (dappChainId !== newChainId) {
                        dappChainId = newChainId
                        const chainIdHex = Utils.chainIdToHex(newChainId)

                        providerStateChanged()
                        chainChangedEvent(chainIdHex)
                    }
                }

                setConnected(true)
            } catch (error) {
                console.error("[ConnectorManager] Error processing connected signal:", error)
            }
        }

        function onDisconnected(payload) {
            try {
                const data = JSON.parse(payload)
                if (!shouldProcessSignal(data)) return
                clearState()
            } catch (error) {
                console.error("[ConnectorManager] Error processing disconnected signal:", error)
            }
        }

        function onConnectorCallRPCResult(requestId, payload) {
            // Emit to Eip1193ProviderAdapter → ethereum_wrapper.js
            requestCompletedEvent({
                requestId: requestId,
                response: payload
            })
        }

        function onChainIdSwitched(payload) {
            try {
                const data = JSON.parse(payload)

                if (!shouldProcessSignal(data)) return

                const chainIdDecimal = Utils.parseChainId(data.chainId)

                if (dappChainId !== chainIdDecimal) {
                    dappChainId = chainIdDecimal
                    const chainIdHex = Utils.chainIdToHex(chainIdDecimal)

                    providerStateChanged()
                    chainChangedEvent(chainIdHex)
                }
            } catch (error) {
                console.error("[ConnectorManager] Error processing chainIdSwitched signal:", error)
            }
        }

        function onAccountChanged(payload) {
            try {
                const data = JSON.parse(payload)
                if (!shouldProcessSignal(data)) return
                const newAccounts = data.sharedAccount ? [data.sharedAccount] : []
                updateAccounts(newAccounts)
            } catch (error) {
                console.error("[ConnectorManager] Error processing accountChanged signal:", error)
            }
        }
    }
}
