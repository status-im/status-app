import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.panels
import shared.controls
import shared.controls.chat
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

Item {
    id: root

    property var selectedAsset
    property string currentCurrency

    property var bestRoutes
    property var getGasNativeCryptoValue: function () {}
    property var getFiatValue: function () {}
    property var formatCurrencyAmount: function () {}
    property var getNetworkName: function () {}

    width: parent.width
    height: visible ? advancedGasSelector.height + Theme.halfPadding : 0

    Column {
        id: advancedGasSelector
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: Theme.halfPadding
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 10

        spacing: Theme.halfPadding

        // Normal transaction
        Repeater {
            model: root.bestRoutes
            StatusListItem {
                id: listItem
                color: Theme.palette.statusListItem.backgroundColor
                width: parent.width
                asset.name: "tiny/gas"
                asset.color: Theme.palette.directColor1
                statusListItemIcon.active: true
                statusListItemIcon.opacity: modelData.isFirstSimpleTx
                title: qsTr("%1 transaction fee").arg(root.getNetworkName(modelData.fromNetwork))
                property string gasSymbol: Utils.getNativeTokenSymbol(modelData.fromNetwork)
                property string gasTokenKey: Utils.getNativeTokenKey(modelData.fromNetwork)
                subTitle: {
                    let primaryFee = root.formatCurrencyAmount(decimalTotalGasAmount, gasSymbol)
                    if (modelData.gasFees.eip1559Enabled && modelData.gasFees.l1GasFee > 0) {
                        return qsTr("L1 fee: %1\nL2 fee: %2")
                        .arg(root.formatCurrencyAmount(decimalTotalGasAmountL1, gasSymbol))
                        .arg(primaryFee)
                    }
                    return primaryFee
                }
                property double decimalTotalGasAmountL1: {
                    const l1FeeInGWei = modelData.gasFees.l1GasFee
                    const l1FeeInEth = Utils.calculateGasCost(modelData.fromNetwork, l1FeeInGWei, modelData.gasAmount)
                    return l1FeeInEth
                }

                property double decimalTotalGasAmount: {
                    let maxFees = modelData.gasFees.maxFeePerGasM
                    let gasPrice = modelData.gasFees.eip1559Enabled ? maxFees : modelData.gasFees.gasPrice
                    return root.getGasNativeCryptoValue(gasPrice, modelData.gasAmount, modelData.fromNetwork)
                }

                property double totalGasAmountFiat: root.getFiatValue(decimalTotalGasAmount, gasTokenKey) + root.getFiatValue(decimalTotalGasAmountL1, gasTokenKey)

                statusListItemSubTitle.width: listItem.width/2 - Theme.smallPadding
                statusListItemSubTitle.elide: Text.ElideMiddle
                statusListItemSubTitle.wrapMode: Text.NoWrap
                components: [
                    StatusBaseText {
                        Layout.alignment: Qt.AlignRight
                        text: root.formatCurrencyAmount(totalGasAmountFiat, root.currentCurrency)
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                ]
            }
        }

        // Approval transaction
        Repeater {
            model: root.bestRoutes
            StatusListItem {
                id: listItem1
                color: Theme.palette.statusListItem.backgroundColor
                width: parent.width
                asset.name: "tiny/checkmark"
                asset.color: Theme.palette.directColor1
                statusListItemIcon.active: true
                statusListItemIcon.opacity: modelData.isFirstSimpleTx
                title: qsTr("Approve %1 %2 Bridge").arg(root.getNetworkName(modelData.fromNetwork)).arg(root.selectedAsset.symbol)
                property double approvalGasFees: modelData.approvalGasFees
                property string approvalGasFeesSymbol: Utils.getNativeTokenSymbol(modelData.fromNetwork)
                property string approvalGasFeesTokenKey: Utils.getNativeTokenKey(modelData.fromNetwork)
                property double approvalGasFeesFiat: root.getFiatValue(approvalGasFees, approvalGasFeesTokenKey)
                subTitle: root.formatCurrencyAmount(approvalGasFees, approvalGasFeesSymbol)
                statusListItemSubTitle.width: listItem1.width/2 - Theme.smallPadding
                statusListItemSubTitle.elide: Text.ElideMiddle
                statusListItemSubTitle.wrapMode: Text.NoWrap
                visible: modelData.approvalRequired
                components: [
                    StatusBaseText {
                        Layout.alignment: Qt.AlignRight
                        text:  root.formatCurrencyAmount(approvalGasFeesFiat, root.currentCurrency)
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                ]
            }
        }

        // Bridge
        Repeater {
            id: bridgeRepeater
            model: root.bestRoutes
            delegate: StatusListItem {
                id: listItem2
                color: Theme.palette.statusListItem.backgroundColor
                width: parent.width
                asset.name: "tiny/bridge"
                asset.color: Theme.palette.directColor1
                statusListItemIcon.active: true
                statusListItemIcon.opacity: modelData.isFirstBridgeTx
                title: qsTr("%1 -> %2 bridge").arg(root.getNetworkName(modelData.fromNetwork)).arg(root.getNetworkName(modelData.toNetwork))
                property double tokenFees: modelData.tokenFees
                property double tokenFeesFiat: {
                    const selectedAssetTokenKey = SQUtils.ModelUtils.get(root.selectedAsset.tokens, modelData.fromNetwork, "key")
                    return root.getFiatValue(tokenFees, selectedAssetTokenKey)
                }
                subTitle: root.formatCurrencyAmount(tokenFees, root.selectedAsset.symbol)
                visible: modelData.bridgeName !== "Transfer"
                statusListItemSubTitle.width: 100
                statusListItemSubTitle.elide: Text.ElideMiddle
                components: [
                    StatusBaseText {
                        Layout.alignment: Qt.AlignRight
                        text: root.formatCurrencyAmount(tokenFeesFiat, root.currentCurrency)
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                ]
            }
        }
    }
}
