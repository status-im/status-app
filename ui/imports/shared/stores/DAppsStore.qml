import QtQuick

import StatusQ.Core.Utils

import utils

QObject {
    id: root

    required property var controller

    signal signingResult(string topic, string id, string data)

    signal estimatedTimeResponse(string topic, int timeCategory, bool success)
    signal suggestedFeesResponse(string topic, var suggestedFeesJsonObj, bool success)
    signal estimatedGasResponse(string topic, string gasEstimate, bool success)

    readonly property Connections _signingRequestConnections: Connections {
        target: root.controller
        function onSigningRequested(reason, keyUid, hash, path, address) {
            Global.openSigningPopup(reason, keyUid, hash, path, address)
        }
    }

    readonly property Connections _signingResultConnections: Connections {
        target: Global
        function onSigningResult(reason, signature, keyUid, path, address) {
            if (!reason.startsWith(Constants.signingReason.walletConnect))
                return
            root.controller.onSigningResult(reason, signature)
        }
    }

    function signMessageUnsafe(topic, id, address, message) {
        controller.signMessageUnsafe(topic, id, address, message)
    }

    function signMessage(topic, id, address, message) {
        controller.signMessage(topic, id, address, message)
    }

    function safeSignTypedData(topic, id, address, typedDataJson, chainId, legacy) {
        controller.safeSignTypedData(topic, id, address, typedDataJson, chainId, legacy)
    }

    // Remove leading zeros from hex number as expected by status-go
    function stripLeadingZeros(hexNumber) {
        let fixed = hexNumber.replace(/^0x0*/, '0x')
        return fixed == '0x' ? '0x0' : fixed;
    }

    // Strip leading zeros from numbers as expected by status-go
    function prepareTxForStatusGo(txObj) {
        let tx = Object.assign({}, txObj)
        if (txObj.gasLimit) {
            tx.gasLimit = stripLeadingZeros(txObj.gasLimit)
        }
        if (txObj.gas) {
            tx.gas = stripLeadingZeros(txObj.gas)
        }
        if (txObj.gasPrice) {
            tx.gasPrice = stripLeadingZeros(txObj.gasPrice)
        }
        if (txObj.nonce) {
            tx.nonce = stripLeadingZeros(txObj.nonce)
        }
        if (txObj.maxFeePerGas) {
            tx.maxFeePerGas = stripLeadingZeros(txObj.maxFeePerGas)
        }
        if (txObj.maxPriorityFeePerGas) {
            tx.maxPriorityFeePerGas = stripLeadingZeros(txObj.maxPriorityFeePerGas)
        }
        if (txObj.value) {
            tx.value = stripLeadingZeros(txObj.value)
        }
        return tx
    }

    // Empty maxFeePerGas will fetch the current chain's maxFeePerGas
    // Returns ui/imports/utils -> Constants.TransactionEstimatedTime values
    function requestEstimatedTime(topic, chainId, maxFeePerGasHex) {
        controller.requestEstimatedTime(topic, chainId, maxFeePerGasHex)
    }

    // Returns nim's SuggestedFeesDto; see src/app_service/service/transaction/dto.nim
    // Returns all value initialized to 0 if error
    function requestSuggestedFees(topic, chainId) {
        controller.requestSuggestedFeesJson(topic, chainId)
    }

    function requestGasEstimate(topic, chainId, txObj) {
        try {
            let tx = prepareTxForStatusGo(txObj)
            controller.requestGasEstimate(topic, chainId, JSON.stringify(tx))
        } catch (e) {
            console.error("Failed to prepare tx for status-go", e)
            root.estimatedGasResponse(topic, "", false)
        }
    }

    function signTransaction(topic, id, address, chainId, txObj) {
        let tx = prepareTxForStatusGo(txObj)
        controller.signTransaction(topic, id, address, chainId, JSON.stringify(tx))
    }

    function sendTransaction(topic, id, address, chainId, txObj) {
        let tx = prepareTxForStatusGo(txObj)
        controller.sendTransaction(topic, id, address, chainId, JSON.stringify(tx))
    }

    function hexToDec(hex) {
        return controller.hexToDecBigString(hex)
    }

    // Return just the modified fields { "maxFeePerGas": "0x<...>", "maxPriorityFeePerGas": "0x<...>" }
    function convertFeesInfoToHex(feesInfoJson) {
        return controller.convertFeesInfoToHex(feesInfoJson)
    }

    // Handle async response from controller
    Connections {
        target: controller

        function onSigningResultReceived(topic, id, data) {
            root.signingResult(topic, id, data)
        }

        function onEstimatedTimeResponse(topic, timeCategory) {
            root.estimatedTimeResponse(topic, timeCategory, !!timeCategory)
        }

        function onSuggestedFeesResponse(topic, suggestedFeesJson) {
            try {
                const jsonObj = JSON.parse(suggestedFeesJson)
                root.suggestedFeesResponse(topic, jsonObj, true)
            } catch (e) {
                console.error("Failed to parse suggestedFeesJson", e)
                root.suggestedFeesResponse(topic, {}, false)
                return
            }
        }

        function onEstimatedGasResponse(topic, gasEstimate) {
            root.estimatedGasResponse(topic, gasEstimate, !!gasEstimate)
        }
    }
}
