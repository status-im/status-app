import QtQuick
import QtTest

import StatusQ.Core

import AppLayouts.Wallet.views

import utils

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: componentUnderTest
        TransactionSettings {
            anchors.fill: parent

            fromChainEIP1559Compliant: true
            fromChainNoBaseFee: false
            fromChainNoPriorityFee: false
            nativeTokenSymbol: "ETH"

            currentGasPrice: "0"
            currentBaseFee: "8200000000"
            currentSuggestedMinPriorityFee: "60000000"
            currentSuggestedMaxPriorityFee: "5100000000"
            // ETH send to a new address after Glamsterdam: floor(207,391 raw estimate * 1.05) = 217,760
            currentGasAmount: "217760"
            minGasAmount: "207391"
            currentNonce: 21

            customBaseFeeOrGasPrice: "8.2"
            customPriorityFee: "1"
            customGasAmount: "217760"
            customNonce: "21"

            selectedFeeMode: Constants.FeePriorityModeType.Custom

            fnGetPriceInCurrencyForFee: rawFee => "0.25 USD"
            fnGetPriceInNativeTokenForFee: rawFee => "0.000123 ETH"
            fnGetEstimatedTime: (gasPrice, baseFee, priorityFee) => 0
            fnRawToGas: rawValue => Utils.nativeTokenRawToGas(Constants.chains.mainnetChainId, rawValue)
            fnGasToRaw: gasValue => Utils.nativeTokenGasToRaw(Constants.chains.mainnetChainId, gasValue)
            fnToLocaleStr: value => value
            fnFromLocaleStr: value => value
        }
    }

    property TransactionSettings controlUnderTest: null

    TestCase {
        name: "TransactionSettings"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_customGasAmount_data() {
            return [
                // blocked: below the node estimate (e.g. legacy 21000 for a send to a new address)
                { tag: "legacy 21000 below minimum", amount: "21000", minGas: "207391",
                  blocking: true, message: "Too low" },
                { tag: "just below minimum", amount: "207390", minGas: "207391",
                  blocking: true, message: "Too low" },
                // blocked: above suggested / 1.2, but still below the raw estimate on a 1.05 path
                { tag: "between suggested/1.2 and raw estimate", amount: "190000", minGas: "207391",
                  blocking: true, message: "Too low" },
                // warning only: between the node estimate and the suggestion
                { tag: "exactly minimum", amount: "207391", minGas: "207391",
                  blocking: false, message: "Lower than recommended" },
                { tag: "between minimum and suggested", amount: "210000", minGas: "207391",
                  blocking: false, message: "Lower than recommended" },
                { tag: "suggested", amount: "217760", minGas: "207391",
                  blocking: false, message: "Current:" },
                // values the old fixed 21000..30000000 bounds rejected
                { tag: "self-send 12000 when estimate allows", amount: "12000", minGas: "12000",
                  blocking: false, message: "Lower than recommended" },
                { tag: "zero-value 15000 when estimate allows", amount: "15000", minGas: "15000",
                  blocking: false, message: "Lower than recommended" },
                { tag: "40M", amount: "40000000", minGas: "207391",
                  blocking: false, message: "Much higher" },
                { tag: "3e9", amount: "3000000000", minGas: "207391",
                  blocking: false, message: "Much higher" },
                { tag: "2^32-1", amount: "4294967295", minGas: "207391",
                  blocking: false, message: "Much higher" },
                // blocked: out of the transport range
                { tag: "2^32", amount: "4294967296", minGas: "207391",
                  blocking: true, message: "Must be between" },
                { tag: "zero", amount: "0", minGas: "",
                  blocking: true, message: "Must be between" },
                // no known minimum: nothing below the suggestion is blocked
                { tag: "unknown minimum", amount: "21000", minGas: "",
                  blocking: false, message: "Lower than recommended" },
            ]
        }

        function test_customGasAmount(data) {
            controlUnderTest.minGasAmount = data.minGas
            controlUnderTest.customGasAmount = data.amount

            const input = findChild(controlUnderTest, "customGasAmountInput")
            verify(!!input)
            const confirmButton = findChild(controlUnderTest, "transactionSettingsConfirmButton")
            verify(!!confirmButton)

            compare(confirmButton.enabled, !data.blocking)
            const message = input.bottomLabelMessageLeftCmp.text
            verify(message.startsWith(data.message), "unexpected message: " + message)
        }

        function test_gasAmountsAreFormatted_data() {
            return [
                { tag: "minimum", amount: "21000", shown: 207391 },
                { tag: "recommended", amount: "210000", shown: 217760 },
                { tag: "current", amount: "217760", shown: 217760 },
                { tag: "maximum", amount: "4294967296", shown: 4294967295 },
            ]
        }

        function test_gasAmountsAreFormatted(data) {
            controlUnderTest.customGasAmount = data.amount
            const input = findChild(controlUnderTest, "customGasAmountInput")
            verify(!!input)
            const message = input.bottomLabelMessageLeftCmp.text
            const formatted = LocaleUtils.numberToLocaleString(data.shown, 0)
            verify(message.includes(formatted), "expected " + formatted + " in: " + message)
        }

        function test_invalidInputBlocks_data() {
            return [
                { tag: "negative", amount: "-1" },
                { tag: "non-numeric", amount: "abc" },
                { tag: "fractional", amount: "21000.5" },
                { tag: "empty", amount: "" },
            ]
        }

        function test_invalidInputBlocks(data) {
            const input = findChild(controlUnderTest, "customGasAmountInput")
            verify(!!input)
            const confirmButton = findChild(controlUnderTest, "transactionSettingsConfirmButton")
            verify(!!confirmButton)

            input.input.dirty = true
            controlUnderTest.customGasAmount = data.amount

            verify(!input.valid)
            verify(!confirmButton.enabled)
        }
    }
}
