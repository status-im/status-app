import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Wallet.views

import utils

import Storybook

SplitView {
    id: root

    SplitView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        orientation: Qt.Vertical

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.baseColor3

            TransactionSettings {
                id: txSettings
                anchors.centerIn: parent

                fromChainEIP1559Compliant: true
                fromChainNoBaseFee: false
                fromChainNoPriorityFee: false
                nativeTokenSymbol: "ETH"

                currentGasPrice: "0.0"
                currentBaseFee: "8.2"
                currentSuggestedMinPriorityFee: "0.06"
                currentSuggestedMaxPriorityFee: "5.1"
                currentGasAmount: "31500"
                minGasAmount: "26250"
                currentNonce: 21

                normalPrice: "1.45 EUR"
                normalTime: "~60s"
                fastPrice: "1.65 EUR"
                fastTime: "~40s"
                urgentPrice: "1.85 EUR"
                urgentTime: "~15s"

                customBaseFeeOrGasPrice: "6.6"
                customPriorityFee: "7.7"
                customGasAmount: "35000"
                customNonce: "22"

                selectedFeeMode: Constants.FeePriorityModeType.Normal

                fnGetPriceInCurrencyForFee: function(feeInWei) {
                    return "0.25 USD"
                }

                fnGetPriceInNativeTokenForFee: function(feeInWei) {
                    return "0.000123 ETH"
                }

                fnGetEstimatedTime: function(gasPrice, baseFeeInWei, priorityFeeInWei) {
                    return 0
                }

                fnRawToGas: function(rawValue) {
                    return Utils.nativeTokenRawToGas(Constants.chains.mainnetChainId, rawValue)
                }

                fnGasToRaw: function(gasValue) {
                    return Utils.nativeTokenGasToRaw(Constants.chains.mainnetChainId, gasValue)
                }

                fnToLocaleStr: function(value) {
                    let amount = Utils.stripTrailingZeros(value)
                    return amount.replace(".", Qt.locale().decimalPoint)
                }

                fnFromLocaleStr: function (value) {
                    return value.replace(Qt.locale().decimalPoint, ".")
                }

                onConfirmClicked: {
                    logs.logEvent("confirm clicked...")
                    logs.logEvent(`selected fee mode: ${txSettings.selectedFeeMode}`)
                    if (selectedFeeMode === Constants.FeePriorityModeType.Custom) {
                        logs.logEvent(`selected customBaseFeeOrGasPrice...${txSettings.customBaseFeeOrGasPrice}`)
                        logs.logEvent(`selected customPriorityFee...${txSettings.customPriorityFee}`)
                        logs.logEvent(`selected customGasAmount...${txSettings.customGasAmount}`)
                        logs.logEvent(`selected customNonce...${txSettings.customNonce}`)
                    }
                }
            }
        }

        Logs {
            id: logs
        }

        LogsView {
            clip: true

            SplitView.preferredHeight: 150
            SplitView.fillWidth: true

            logText: logs.logText
        }
    }

    Pane {
        SplitView.preferredWidth: 300

    }
}

// category: Panel
