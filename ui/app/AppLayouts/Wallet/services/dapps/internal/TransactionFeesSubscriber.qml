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
    // gasLimit -> hex gas to show the fees for and sign with: the larger of the dApp's gas and
    // our estimate; unset until the estimate answered
    readonly property var gasLimit: d.gasResponse
    // gasEstimated -> our estimate answered, or failed with the dApp's gas to fall back on
    readonly property bool gasEstimated: d.gasEstimated

    function setFees(fees) {
        if (d.feesResponse === fees) {
            return
        }
        d.feesResponse = fees
        d.resetFees()
    }

    // the dApp's gas, hex
    function setDappGas(gas) {
        d.dappGas = gas || ""
        d.resolveGas()
    }

    // our buffered estimate, hex; empty when it failed
    function setGasEstimate(gas) {
        d.estimatedGas = gas || ""
        // without the dApp's gas to fall back on a failed estimate is asked again
        d.gasEstimated = !!d.estimatedGas || !!d.dappGas
        d.resolveGas()
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
        property var gasResponse
        property string dappGas
        property string estimatedGas
        property bool gasEstimated: false
        // Eth max fee in Gwei
        property var computedFees
        // feesResponse with additional `maxFeePerGas` property based on selectedFeesMode
        property var computedFeesInfo

        function resolveGas() {
            if (!d.gasEstimated)
                return
            let gas = d.estimatedGas || d.dappGas
            if (!!d.estimatedGas && !!d.dappGas) {
                const BigOps = SQUtils.AmountsArithmetic
                const estimated = BigOps.fromString(String(root.hexToDec(d.estimatedGas)))
                const dapp = BigOps.fromString(String(root.hexToDec(d.dappGas)))
                gas = dapp.cmp(estimated) === 1 ? d.dappGas : d.estimatedGas
            }
            if (d.gasResponse === gas)
                return
            d.gasResponse = gas
            d.resetFees()
        }

        function resetFees() {
            if (!d.feesResponse) {
                return
            }
            if (!gasResponse) {
                return
            }
            try {
                d.computedFees = getEstimatedMaxFees()
                d.computedFeesInfo = d.feesResponse
                d.computedFeesInfo.maxFeePerGas = getFeesForFeesMode(d.feesResponse)
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