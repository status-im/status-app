import QtQuick
import QtTest

import AppLayouts.Browser.provider.qml

/// A dApp request is a Keep-alive reason only while it awaits the user: the
/// connector asked for their approval (connect, sign, send) and no answer came
/// back. Plain RPC traffic, however steady, never holds the Browser.
Item {
    id: root

    Component {
        id: controllerComponent

        QtObject {
            signal connected(string payload)
            signal disconnected(string payload)
            signal connectorCallRPCResult(int requestId, string payload)
            signal chainIdSwitched(string payload)
            signal accountChanged(string payload)
            signal connectRequested(string requestId, string payload)
            signal sendTransaction(string requestId, string payload)
            signal sign(string requestId, string payload)

            function connectorCallRPC(requestId, json) {}
        }
    }

    Component {
        id: managerComponent

        ConnectorManager {
            dappUrl: "https://dapp.example/"
            dappOrigin: "https://dapp.example"
        }
    }

    TestCase {
        name: "BrowserConnectorPending"

        function makeManager() {
            const controller = createTemporaryObject(controllerComponent, root)
            const manager = createTemporaryObject(managerComponent, root,
                                                  { connectorController: controller })
            verify(!!manager)
            return { controller, manager }
        }

        function dapp(extra) {
            return JSON.stringify(Object.assign({ url: "https://dapp.example" }, extra ?? {}))
        }

        function test_plainRpcTrafficHoldsNothing() {
            const { controller, manager } = makeManager()

            manager.request({ method: "eth_blockNumber", requestId: 1 })
            manager.request({ method: "eth_call", requestId: 2 })

            verify(!manager.hasPendingRequests)
            controller.connectorCallRPCResult(1, "{}")
            controller.connectorCallRPCResult(2, "{}")
            verify(!manager.hasPendingRequests)
        }

        function test_aSignAwaitingTheUserHoldsUntilAnswered() {
            const { controller, manager } = makeManager()
            manager.request({ method: "eth_blockNumber", requestId: 1 })
            manager.request({ method: "personal_sign", requestId: 2 })

            controller.sign("sr-1", dapp({ method: "personal_sign" }))
            verify(manager.hasPendingRequests)

            controller.connectorCallRPCResult(1, "{}")
            verify(manager.hasPendingRequests, "other traffic does not answer it")

            controller.connectorCallRPCResult(2, "{}")
            verify(!manager.hasPendingRequests)
        }

        function test_connectAndSendAreUserGated() {
            const { controller, manager } = makeManager()
            manager.request({ method: "eth_requestAccounts", requestId: 1 })
            manager.request({ method: "eth_sendTransaction", requestId: 2 })

            controller.connectRequested("cr-1", dapp({ clientId: manager.clientId }))
            controller.sendTransaction("tx-1", dapp())
            verify(manager.hasPendingRequests)

            controller.connectorCallRPCResult(1, "{}")
            verify(manager.hasPendingRequests)
            controller.connectorCallRPCResult(2, "{}")
            verify(!manager.hasPendingRequests)
        }

        function test_anotherOriginsApprovalIsNotOurs() {
            const { controller, manager } = makeManager()
            manager.request({ method: "eth_sendTransaction", requestId: 1 })

            controller.sendTransaction("tx-1", JSON.stringify({ url: "https://other.example" }))

            verify(!manager.hasPendingRequests)
        }

        function test_anotherClientsConnectIsNotOurs() {
            const { controller, manager } = makeManager()
            manager.request({ method: "eth_requestAccounts", requestId: 1 })

            controller.connectRequested("cr-1", dapp({ clientId: "someone-else" }))

            verify(!manager.hasPendingRequests)
        }
    }
}
