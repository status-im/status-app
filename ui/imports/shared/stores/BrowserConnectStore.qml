import QtQuick

import StatusQ.Core.Utils as SQUtils

SQUtils.QObject {
    id: root

    required property var controller
    
    // Signals driven by the dApp
    signal connectRequested(string requestId, string dappJson)
    signal sendTransaction(string requestId, string requestJson)
    signal sign(string requestId, string dappJson)

    signal connected(string dappJson)
    signal disconnected(string dappJson)

    // Responses to user actions
    signal approveConnectResponse(string id, bool error)
    signal rejectConnectResponse(string id, bool error)

    signal approveTransactionResponse(string topic, string requestId, bool error)
    signal rejectTransactionResponse(string topic, string requestId, bool error)
    signal approveSignResponse(string topic, string requestId, bool error)
    signal rejectSignResponse(string topic, string requestId, bool error)

    function approveConnection(id, account, chainId) {
        return controller.approveConnection(id, account, chainId)
    }

    function rejectConnection(id, error) {
        return controller.rejectConnection(id, error)
    }

    function approveTransaction(topic, requestId, signature) {
        return controller.approveTransaction(topic, requestId, signature)
    }

    function rejectTransaction(topic, requestId, error) {
        return controller.rejectTransaction(topic, requestId, error)
    }

    function disconnect(id, clientId) {
        return controller.disconnect(id, clientId || "")
    }

    function getDApps() {
        return controller.getDApps()
    }

    function approveSign(topic, requestId, signature) {
        return controller.approveSigning(topic, requestId, signature)
    }

    function rejectSign(topic, requestId) {
        return controller.rejectSigning(topic, requestId)
    }

    Connections {
        target: controller

        function onConnectRequested(requestId, dappJson) {
            root.connectRequested(requestId, dappJson)
        }

        function onSendTransaction(requestId, requestJson) {
            root.sendTransaction(requestId, requestJson)
        }

        function onSign(requestId, dappJson) {
            root.sign(requestId, dappJson)
        }

        function onConnected(dappJson) {
            root.connected(dappJson)
        }

        function onDisconnected(dappJson) {
            root.disconnected(dappJson)
        }

        function onApproveConnectResponse(id, error) {
            root.approveConnectResponse(id, error)
        }

        function onRejectConnectResponse(id, error) {
            root.rejectConnectResponse(id, error)
        }

        function onApproveTransactionResponse(topic, requestId, error) {
            root.approveTransactionResponse(topic, requestId, error)
        }

        function onRejectTransactionResponse(topic, requestId, error) {
            root.rejectTransactionResponse(topic, requestId, error)
        }

        function onApproveSignResponse(topic, requestId, error) {
            root.approveSignResponse(topic, requestId, error)
        }

        function onRejectSignResponse(topic, requestId, error) {
            root.rejectSignResponse(topic, requestId, error)
        }
    }
}