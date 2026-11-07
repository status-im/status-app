import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

SQUtils.QObject {
    id: root

    /*
        Input properties
    */
    // standard transaction object
    required property var txObject
    // subscriber id
    required property string key
    // chainId -> chain id for the transaction
    required property int chainId
    // active specifies if the subscriber has an active subscription
    required property bool active
    // selectedFeesMode -> selected fees mode. Defaults to Constants.TransactionFeesMode.Medium
    property int selectedFeesMode: Constants.TransactionFeesMode.Medium
    // gasEstimateTxObject -> the transaction as it will be signed, without gas; re-estimated when it changes
    property var gasEstimateTxObject: txObject

    // Required function to be implemented by the subscriber
    required property var hexToDec /*(hexValue) => decValue*/

    /*
        Published properties
    */
    // estimatedTimeResponse -> maps to Constants.TransactionEstimatedTime
    readonly property int estimatedTimeResponse: d.estimatedTimeResponse
    // maxEthFee -> Big number in Gwei. Represens the total fees for the transaction
    readonly property var maxEthFee: d.computedFees
    // feesInfo -> status-go fees info with updated maxFeePerGas based on selectedFeesMode
    readonly property var feesInfo: d.computedFeesInfo
    // gasLimit -> hex gas to sign with: the larger of the dApp's gas and our estimate; unset until
    // the estimate for the current gasEstimateTxObject answered
    readonly property string gasLimit: d.gasEstimated ? d.gasResponse : ""
    // gasEstimated -> our estimate for gasEstimateTxObject answered
    readonly property bool gasEstimated: d.gasEstimated
    // gasEstimateFailed -> our estimate for gasEstimateTxObject failed; asked again, nothing is signed meanwhile
    readonly property bool gasEstimateFailed: !d.estimatedGas && d.estimateIsCurrent

    function setFees(fees) {
        if (d.feesResponse === fees) {
            return
        }
        d.feesResponse = fees
        d.resetFees()
    }

    // our buffered estimate, hex, for the transaction with txKey (see txKey()); empty when it failed
    function setGasEstimate(gas, txKey) {
        d.estimatedGas = gas || ""
        d.estimatedTxKey = txKey
    }

    function txKey(tx) {
        return JSON.stringify(tx ?? null)
    }

    function setEstimatedTime(estimatedTime) {
        if(!estimatedTime) {
            estimatedTime = Constants.TransactionEstimatedTime.Unknown
            return
        }
        d.estimatedTimeResponse = estimatedTime
    }

    QtObject {
        id: d

        property int estimatedTimeResponse: Constants.TransactionEstimatedTime.Unknown
        property var feesResponse
        // the dApp's gas, hex
        readonly property string dappGas: !!root.txObject ? (root.txObject.gas || root.txObject.gasLimit || "") : ""
        property string estimatedGas
        readonly property string estimateTxKey: root.txKey(root.gasEstimateTxObject)
        property string estimatedTxKey
        // the last answer is for the current transaction
        readonly property bool estimateIsCurrent: estimatedTxKey === estimateTxKey
        // the dApp's gas alone is never used: a failed estimate means the tx would likely fail
        // while a changed transaction is re-estimated, the last gas only shows the fees; a failure clears them
        readonly property bool gasEstimated: !!estimatedGas && estimateIsCurrent
        readonly property string gasResponse: {
            if (!estimatedGas || !dappGas)
                return estimatedGas
            const BigOps = SQUtils.AmountsArithmetic
            const estimated = BigOps.fromString(root.hexToDec(estimatedGas))
            const dapp = BigOps.fromString(root.hexToDec(dappGas))
            return dapp.cmp(estimated) === 1 ? dappGas : estimatedGas
        }
        onGasResponseChanged: resetFees()
        // Eth max fee in Gwei
        property var computedFees
        // feesResponse with additional `maxFeePerGas` property based on selectedFeesMode
        property var computedFeesInfo

        function resetFees() {
            if (!d.feesResponse) {
                return
            }
            try {
                // independent of the gas, so the gas can be estimated with these fees
                const feesInfo = Object.assign({}, d.feesResponse)
                feesInfo.maxFeePerGas = getFeesForFeesMode(d.feesResponse)
                d.computedFeesInfo = feesInfo
                d.computedFees = gasResponse ? getEstimatedMaxFees() : null
            } catch (e) {
                console.error("Failed to compute fees", e, e.stack)
            }
        }

        function getFeesForFeesMode(feesObj) {
            if (!(feesObj.hasOwnProperty("maxFeePerGasLow") &&
                  feesObj.hasOwnProperty("maxFeePerGasMedium") &&
                  feesObj.hasOwnProperty("maxFeePerGasHigh"))) {
                print ("feesObj", JSON.stringify(feesObj))
                throw new Error("inappropriate fees object provided")
            }
            const BigOps = SQUtils.AmountsArithmetic
            if (!feesObj.eip1559Enabled && !!feesObj.gasPrice) {
                return feesObj.gasPrice
            }

            switch (root.selectedFeesMode) {
            case Constants.FeesMode.Low:
                return feesObj.maxFeePerGasLow
            case Constants.FeesMode.Medium:
                return feesObj.maxFeePerGasMedium
            case Constants.FeesMode.High:
                return feesObj.maxFeePerGasHigh
            default:
                throw new Error("unknown selected mode")
            }
        }

        function getEstimatedMaxFees() {
            // Note: Use the received fee arguments only once!
            // Complete what's missing with the suggested fees
            const BigOps = SQUtils.AmountsArithmetic
            const gasLimitStr = root.hexToDec(d.gasResponse)

            const gasLimit = BigOps.fromString(gasLimitStr)
            const maxFeesPerGas = BigOps.fromNumber(getFeesForFeesMode(d.feesResponse))
            const l1GasFee = d.feesResponse.l1GasFee ? BigOps.fromNumber(d.feesResponse.l1GasFee)
                                                    : BigOps.fromNumber(0)

            let maxGasFee = BigOps.times(gasLimit, maxFeesPerGas).plus(l1GasFee)
            return maxGasFee
        }

        Component.onCompleted: {
            resetFees()
        }
    }
}