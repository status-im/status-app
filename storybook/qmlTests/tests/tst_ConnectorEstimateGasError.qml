import QtQuick
import QtTest

import AppLayouts.Browser.provider.qml

import "../../../ui/app/AppLayouts/Browser/provider/qml/Utils.js" as Utils

Item {
    id: root

    readonly property string insufficientFundsPayload: JSON.stringify({
        jsonrpc: "2.0",
        id: 7,
        error: { code: -32000, message: "insufficient funds for gas * price + value" }
    })

    readonly property string gasExceedsPayload: JSON.stringify({
        jsonrpc: "2.0",
        id: 9,
        error: { code: -32000, message: "gas required exceeds allowance (0)" }
    })

    readonly property string estimateSuccessPayload: JSON.stringify({
        jsonrpc: "2.0",
        id: 8,
        result: "0x5208"
    })

    Component {
        id: mockConnectorControllerComponent

        QtObject {
            id: mock

            signal connected(string payload)
            signal disconnected(string payload)
            signal connectorCallRPCResult(int requestId, string payload)
            signal chainIdSwitched(string payload)
            signal accountChanged(string payload)

            property var calls: []

            function connectorCallRPC(requestId, json) {
                calls.push({ requestId: requestId, json: json })
            }

            function deliver(requestId, payload) {
                connectorCallRPCResult(requestId, payload)
            }
        }
    }

    Component {
        id: harnessComponent

        Item {
            property var controller

            property alias manager: manager
            property alias errorSpy: errorSpy
            property var completed: []

            ConnectorManager {
                id: manager
                connectorController: controller

                onRequestCompletedEvent: (payload) => completed.push(payload)
            }

            SignalSpy {
                id: errorSpy
                target: manager
                signalName: "walletRpcUserError"
            }
        }
    }

    TestCase {
        name: "ConnectorEstimateGasError"
        when: windowShown

        function test_classifier_matchesEstimateGasInsufficientFundsOnly() {
            verify(Utils.isInsufficientGasFeeError("eth_estimateGas", root.insufficientFundsPayload))
            verify(Utils.isInsufficientGasFeeError("linea_estimateGas", root.gasExceedsPayload))
            verify(!Utils.isInsufficientGasFeeError("eth_estimateGas", root.estimateSuccessPayload))
            verify(!Utils.isInsufficientGasFeeError("eth_call", root.insufficientFundsPayload))
        }

        function test_estimateGasInsufficientFunds_emitsUserErrorAndForwardsPayload() {
            const mock = createTemporaryObject(mockConnectorControllerComponent, root)
            const harness = createTemporaryObject(harnessComponent, root, { controller: mock })

            const response = harness.manager.request({
                method: "eth_estimateGas",
                requestId: 7,
                params: [{ from: "0x1" }]
            })
            const parsed = JSON.parse(response)
            compare(parsed.result, null, "request() still returns immediately")
            compare(mock.calls.length, 1)
            compare(JSON.parse(mock.calls[0].json).method, "eth_estimateGas")

            mock.deliver(7, root.insufficientFundsPayload)

            compare(harness.errorSpy.count, 1)
            compare(harness.errorSpy.signalArguments[0][0], ConnectorConstants.insufficientNetworkFeeMessage)
            compare(harness.completed.length, 1)
            compare(harness.completed[0].requestId, 7)
            compare(harness.completed[0].response, root.insufficientFundsPayload)
        }

        function test_estimateGasSuccess_doesNotEmitUserError() {
            const mock = createTemporaryObject(mockConnectorControllerComponent, root)
            const harness = createTemporaryObject(harnessComponent, root, { controller: mock })

            harness.manager.request({ method: "eth_estimateGas", requestId: 8 })
            mock.deliver(8, root.estimateSuccessPayload)

            compare(harness.errorSpy.count, 0)
            compare(harness.completed.length, 1)
            compare(harness.completed[0].response, root.estimateSuccessPayload)
        }

        function test_otherMethodInsufficientFunds_doesNotEmitUserError() {
            const mock = createTemporaryObject(mockConnectorControllerComponent, root)
            const harness = createTemporaryObject(harnessComponent, root, { controller: mock })

            harness.manager.request({ method: "eth_call", requestId: 11 })
            mock.deliver(11, root.insufficientFundsPayload)

            compare(harness.errorSpy.count, 0)
            compare(harness.completed.length, 1)
            compare(harness.completed[0].response, root.insufficientFundsPayload)
        }
    }
}
