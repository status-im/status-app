import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

import AppLayouts.Wallet

import shared.controls
import shared.popups
import utils

import AppLayouts.Wallet

Rectangle {
    id: root

    objectName: "transactionSettings"

    required property bool fromChainEIP1559Compliant
    required property bool fromChainNoBaseFee
    required property bool fromChainNoPriorityFee
    required property string nativeTokenSymbol

    required property string currentGasPrice
    required property string currentBaseFee
    required property string currentSuggestedMinPriorityFee
    required property string currentSuggestedMaxPriorityFee
    required property string currentGasAmount
    required property int currentNonce

    property alias normalPrice: optionNormal.subText
    property alias normalTime: optionNormal.additionalText

    property alias fastPrice: optionFast.subText
    property alias fastTime: optionFast.additionalText

    property alias urgentPrice: optionUrgent.subText
    property alias urgentTime: optionUrgent.additionalText

    property alias customBaseFeeOrGasPrice: customBaseFeeOrGasPriceInput.text
    property alias customBaseFeeOrGasPriceDirty: customBaseFeeOrGasPriceInput.input.dirty

    property alias customPriorityFee: customPriorityFeeInput.text
    property alias customPriorityFeeDirty: customPriorityFeeInput.input.dirty

    property alias customGasAmount: customGasAmountInput.text
    property alias customGasAmountDirty: customGasAmountInput.input.dirty

    property alias customNonce: customNonceInput.text
    property alias customNonceDirty: customNonceInput.input.dirty

    required property int selectedFeeMode

    required property var fnGetPriceInCurrencyForFee
    required property var fnGetPriceInNativeTokenForFee
    required property var fnGetEstimatedTime
    required property var fnRawToGas
    required property var fnGasToRaw
    required property var fnToLocaleStr
    required property var fnFromLocaleStr

    signal confirmClicked()
    signal cancelClicked()

    color: Theme.palette.statusModal.backgroundColor
    radius: Theme.radius

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    focus: true

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            root.cancelClicked()
        }
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
        }
    }

    function recalculateCustomPrice() {
        d.recalculateCustomPrice()
    }

    Component.onCompleted: root.forceActiveFocus()

    QtObject {
        id: d

        readonly property bool customMode: root.selectedFeeMode === Constants.FeePriorityModeType.Custom

        function showAlert(title, text, note, url) {
            infoBox.title = title
            infoBox.text = text
            infoBox.note = note
            infoBox.url = url
            infoBox.active = true
        }

        function recalculatecustomBaseFeeOrGasPricePrice() {
            if (root.fromChainEIP1559Compliant && root.fromChainNoBaseFee) {
                return
            }
            if (!customBaseFeeOrGasPriceInput.text) {
                customBaseFeeOrGasPriceInput.bottomLabelMessageRightCmp.text = ""
                return
            }

            const gp = root.fnFromLocaleStr(customBaseFeeOrGasPriceInput.text)
            const rawValue = root.fnGasToRaw(gp)
            const rawFee = SQUtils.AmountsArithmetic.times(rawValue, SQUtils.AmountsArithmetic.fromString(customGasAmountInput.text)).toString()
            customBaseFeeOrGasPriceInput.bottomLabelMessageRightCmp.text = root.fnGetPriceInNativeTokenForFee(rawFee).toUpperCase()
        }

        function recalculateCustomPriorityFeePrice() {
            if (!root.fromChainEIP1559Compliant || root.fromChainNoPriorityFee) {
                return
            }
            if (!customPriorityFeeInput.text) {
                customPriorityFeeInput.bottomLabelMessageRightCmp.text = ""
                return
            }

            const pf = root.fnFromLocaleStr(customPriorityFeeInput.text)
            const rawValue = root.fnGasToRaw(pf)
            const rawFee = SQUtils.AmountsArithmetic.times(rawValue, SQUtils.AmountsArithmetic.fromString(customGasAmountInput.text)).toString()
            customPriorityFeeInput.bottomLabelMessageRightCmp.text = root.fnGetPriceInNativeTokenForFee(rawFee).toUpperCase()
        }

        function recalculateCustomPrice() {
            if (!customBaseFeeOrGasPriceInput.text || root.fromChainEIP1559Compliant && !customPriorityFeeInput.text || !customGasAmountInput.text) {
                optionCustom.subText = ""
                return
            }

            const gp = root.fnFromLocaleStr(customBaseFeeOrGasPriceInput.text)

            let estimatedTime = 0
            let rawTotalFee = ""
            if (!root.fromChainEIP1559Compliant) {
                rawTotalFee = root.fnGasToRaw(gp)
                estimatedTime = root.fnGetEstimatedTime(rawTotalFee.toFixed(),  "", "")
            } else {
                const pf = root.fnFromLocaleStr(customPriorityFeeInput.text)
                const rawBaseFee = root.fnGasToRaw(gp)
                const rawPriorityFee = root.fnGasToRaw(pf)
                rawTotalFee = SQUtils.AmountsArithmetic.sum(rawBaseFee, rawPriorityFee)
                estimatedTime = root.fnGetEstimatedTime("", rawTotalFee.toFixed(), rawPriorityFee.toFixed())
            }

            const rawFee = SQUtils.AmountsArithmetic.times(rawTotalFee, SQUtils.AmountsArithmetic.fromString(customGasAmountInput.text)).toFixed()

            optionCustom.subText = root.fnGetPriceInCurrencyForFee(rawFee)
            optionCustom.additionalText = WalletUtils.formatEstimatedTime(estimatedTime)
        }
    }

    Loader {
        id: infoBox
        anchors.centerIn: root
        active: false

        property string title
        property string text
        property string note
        property string url

        sourceComponent: AlertPopup {
            title: infoBox.title

            width: root.width - 2 * 20

            acceptBtnText: qsTr("Got it")
            cancelBtn.text: !!infoBox.url? qsTr("Read more") : ""
            cancelBtn.icon.name: "external-link"
            cancelBtn.visible: !!infoBox.url

            alertLabel.text: infoBox.text
            alertNote.visible: !!infoBox.note
            alertNote.text: infoBox.note
            alertNote.color: Theme.palette.baseColor1

            onCancelClicked: Global.requestOpenLink(infoBox.url)

            onClosed: {
                infoBox.active = false
            }
        }

        onLoaded: {
            infoBox.item.open()
        }
    }

    StatusScrollView {
        id: scrollView

        anchors.fill: parent
        contentWidth: availableWidth
        contentHeight: layout.implicitHeight
        padding: 0
        ScrollBar.vertical.implicitWidth: Math.max(Theme.halfPadding, 8)

        ColumnLayout {
            id: layout

            width: scrollView.availableWidth

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.margins: 20

                spacing: Theme.padding

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    StatusBaseText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: qsTr("Transaction settings")
                        font.pixelSize: Theme.secondaryAdditionalTextSize
                        font.bold: true
                        elide: Text.ElideMiddle
                    }

                    StatusFlatButton {
                        objectName: "transactionSettingsCloseButton"
                        icon.name: "close"
                        onClicked: root.cancelClicked()
                    }
                }

                RowLayout {
                    id: options
                    Layout.fillWidth: true
                    spacing: 12

                    StatusFeeOption {
                        id: optionNormal
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        type: Constants.FeePriorityModeType.Normal
                        mainText: WalletUtils.getFeeTextForFeeMode(type)
                        icon: WalletUtils.getIconForFeeMode(type)
                        selected: root.selectedFeeMode === Constants.FeePriorityModeType.Normal
                        showSubText: true
                        showAdditionalText: true

                        onClicked: root.selectedFeeMode = Constants.FeePriorityModeType.Normal
                    }

                    StatusFeeOption {
                        id: optionFast
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        type: Constants.FeePriorityModeType.Fast
                        enabled: root.fromChainEIP1559Compliant
                        mainText: WalletUtils.getFeeTextForFeeMode(type)
                        icon: WalletUtils.getIconForFeeMode(type)
                        selected: root.selectedFeeMode === Constants.FeePriorityModeType.Fast
                        showSubText: true
                        showAdditionalText: true

                        GaussianBlur {
                            anchors.fill: parent
                            visible: !root.fromChainEIP1559Compliant
                            source: parent
                            radius: 4
                            samples: 4
                            transparentBorder: true
                        }

                        onClicked: root.selectedFeeMode = Constants.FeePriorityModeType.Fast
                    }

                    StatusFeeOption {
                        id: optionUrgent
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        enabled: root.fromChainEIP1559Compliant
                        type: Constants.FeePriorityModeType.Urgent
                        mainText: WalletUtils.getFeeTextForFeeMode(type)
                        icon: WalletUtils.getIconForFeeMode(type)
                        selected: root.selectedFeeMode === Constants.FeePriorityModeType.Urgent
                        showSubText: true
                        showAdditionalText: true

                        GaussianBlur {
                            anchors.fill: parent
                            visible: !root.fromChainEIP1559Compliant
                            source: parent
                            radius: 4
                            samples: 4
                            transparentBorder: true
                        }

                        onClicked: root.selectedFeeMode = Constants.FeePriorityModeType.Urgent
                    }

                    StatusFeeOption {
                        id: optionCustom
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        type: Constants.FeePriorityModeType.Custom
                        mainText: WalletUtils.getFeeTextForFeeMode(type)
                        icon: WalletUtils.getIconForFeeMode(type)
                        selected: root.selectedFeeMode === Constants.FeePriorityModeType.Custom
                        showSubText: !!selected
                        showAdditionalText: !!selected
                        unselectedText: qsTr("Set your own fees & nonce")

                        onClicked: root.selectedFeeMode = Constants.FeePriorityModeType.Custom
                    }
                }

                StatusBaseText {
                    Layout.preferredWidth: parent.width
                    visible: !d.customMode
                    text: {
                        if (!root.fromChainEIP1559Compliant) {
                            if (optionCustom.hovered || optionCustom.selected) {
                                return qsTr("Set your own base fee, priority fee, gas amount and nonce")
                            }
                            return qsTr("Regular cost option using suggested gas price")
                        }

                        if (optionFast.hovered || optionFast.selected) {
                            return qsTr("Increased gas price, incentivising miners to confirm more quickly")
                        } if (optionUrgent.hovered || optionUrgent.selected) {
                            return qsTr("Highest base and priority fee, ensuring the fastest possible confirmation")
                        } if (optionCustom.hovered || optionCustom.selected) {
                            return qsTr("Set your own base fee, priority fee, gas amount and nonce")
                        }
                        return qsTr("Low cost option using current network base fee and a low priority fee")
                    }
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.tertiaryTextFontSize
                    elide: Text.ElideMiddle
                }

                ShapeRectangle {
                    Layout.preferredWidth: parent.width
                    Layout.preferredHeight: customLayout.height + customLayout.anchors.margins
                    visible: d.customMode

                    ColumnLayout {
                        id: customLayout
                        anchors.left: parent.left
                        anchors.margins: 20
                        width: parent.width - 2 * anchors.margins
                        spacing: 16

                        StatusInput {
                            id: customBaseFeeOrGasPriceInput

                            readonly property bool displayLowBaseFeeOrGasPriceWarning: {
                                if (root.fromChainEIP1559Compliant && root.fromChainNoBaseFee) {
                                    return false
                                }
                                if (!customBaseFeeOrGasPriceInput.text) {
                                    return false
                                }
                                const rawCurrentValue = !root.fromChainEIP1559Compliant?
                                                          SQUtils.AmountsArithmetic.fromString(root.currentGasPrice)
                                                        : SQUtils.AmountsArithmetic.fromString(root.currentBaseFee)
                                const decreasedCurrentValue = SQUtils.AmountsArithmetic.times(rawCurrentValue, SQUtils.AmountsArithmetic.fromString("0.9")) // up to -10% is acceptable
                                const gp = root.fnFromLocaleStr(customBaseFeeOrGasPriceInput.text)
                                const rawEnteredValue = root.fnGasToRaw(gp)
                                return decreasedCurrentValue.cmp(rawEnteredValue) === 1
                            }

                            readonly property bool displayHighBaseFeeOrGasPriceWarning: {
                                if (root.fromChainEIP1559Compliant && root.fromChainNoBaseFee) {
                                    return false
                                }
                                if (!customBaseFeeOrGasPriceInput.text) {
                                    return false
                                }
                                const rawCurrentValue = !root.fromChainEIP1559Compliant?
                                                          SQUtils.AmountsArithmetic.fromString(root.currentGasPrice)
                                                        : SQUtils.AmountsArithmetic.fromString(root.currentBaseFee)
                                const increasedCurrentValue = SQUtils.AmountsArithmetic.times(rawCurrentValue, SQUtils.AmountsArithmetic.fromString("1.2")) // up to 20% higher value is acceptable
                                const gp = root.fnFromLocaleStr(customBaseFeeOrGasPriceInput.text)
                                const rawEnteredValue = root.fnGasToRaw(gp)
                                return rawEnteredValue.cmp(increasedCurrentValue) === 1
                            }

                            Layout.preferredWidth: parent.width
                            Layout.topMargin: 20
                            enabled: !(root.fromChainEIP1559Compliant && root.fromChainNoBaseFee)
                            label: !root.fromChainEIP1559Compliant? qsTr("Gas price") : qsTr("Max base fee")
                            labelIcon: "info"
                            labelIconColor: Theme.palette.baseColor1
                            labelIconClickable: true
                            bottomLabelMessageLeftCmp.color: customBaseFeeOrGasPriceInput.displayLowBaseFeeOrGasPriceWarning
                                                             || customBaseFeeOrGasPriceInput.displayHighBaseFeeOrGasPriceWarning?
                                                                 Theme.palette.miscColor6
                                                               : Theme.palette.baseColor1
                            bottomLabelMessageLeftCmp.text: {
                                const baseFeeOrGasPrice = !root.fromChainEIP1559Compliant?
                                                            root.currentGasPrice
                                                          : root.currentBaseFee

                                return customBaseFeeOrGasPriceInput.displayLowBaseFeeOrGasPriceWarning?
                                            qsTr("Lower than necessary (current %1)").arg(root.fnGetPriceInNativeTokenForFee(baseFeeOrGasPrice).toUpperCase())
                                          : customBaseFeeOrGasPriceInput.displayHighBaseFeeOrGasPriceWarning?
                                                qsTr("Higher than necessary (current %1)").arg(root.fnGetPriceInNativeTokenForFee(baseFeeOrGasPrice).toUpperCase())
                                              : qsTr("Current: %1").arg(root.fnGetPriceInNativeTokenForFee(baseFeeOrGasPrice).toUpperCase())
                            }
                            rightPadding: leftPadding
                            input.rightComponent: StatusBaseText {
                                text: "GWEI"
                                color: Theme.palette.baseColor1
                            }

                            validators: [
                                StatusRegularExpressionValidator {
                                    regularExpression: Constants.regularExpressions.positiveRealNumbers
                                    errorMessage: Constants.errorMessages.positiveRealNumbers
                                }
                            ]

                            onTextChanged: Qt.callLater(() => {
                                                            if (!customBaseFeeOrGasPriceInput.valid) {
                                                                return
                                                            }
                                                            d.recalculatecustomBaseFeeOrGasPricePrice()
                                                            d.recalculateCustomPrice()
                                                        })

                            onLabelIconClicked: {
                                const warning = !root.fromChainEIP1559Compliant?
                                                  qsTr("The gas price you set is the exact amount you’ll pay per unit of gas used. If you set a gas price higher than what’s required for inclusion, the difference will not be refunded. Choose your gas price carefully to avoid overpaying.\n")
                                                : qsTr("When your transaction gets included in the block, any difference between your max base fee and the actual base fee will be refunded.\n")

                                const note = !root.fromChainEIP1559Compliant?
                                               qsTr("Note: the %1 amount shown for this value is calculated:\nGas price (in GWEI) * gas amount").arg(root.nativeTokenSymbol)
                                             : qsTr("Note: the %1 amount shown for this value is calculated:\nMax base fee (in GWEI) * Max gas amount").arg(root.nativeTokenSymbol)

                                d.showAlert(label, warning, note, "")
                            }
                        }

                        StatusInput {
                            id: customPriorityFeeInput

                            readonly property bool displayHigherPriorityFeeWarning: {
                                if (root.fromChainEIP1559Compliant && root.fromChainNoPriorityFee) {
                                    return false
                                }
                                if (!customPriorityFeeInput.text) {
                                    return false
                                }
                                const rawCurrentValue = SQUtils.AmountsArithmetic.fromString(root.currentSuggestedMaxPriorityFee)
                                const pf = root.fnFromLocaleStr(customPriorityFeeInput.text)
                                const rawEnteredValue = root.fnGasToRaw(pf)
                                return rawEnteredValue.cmp(rawCurrentValue) === 1
                            }

                            readonly property bool displayHigherThanBaseFeeWarning: {
                                if (root.fromChainEIP1559Compliant && root.fromChainNoBaseFee) {
                                    return false
                                }
                                if (!customPriorityFeeInput.text || !customBaseFeeOrGasPriceInput.text) {
                                    return false
                                }
                                const gp = root.fnFromLocaleStr(customBaseFeeOrGasPriceInput.text)
                                const rawBaseFeeValue = root.fnGasToRaw(gp)
                                const pf = root.fnFromLocaleStr(customPriorityFeeInput.text)
                                const rawEnteredValue = root.fnGasToRaw(pf)
                                return rawEnteredValue.cmp(rawBaseFeeValue) === 1
                            }

                            Layout.preferredWidth: parent.width
                            visible: root.fromChainEIP1559Compliant
                            enabled: !(root.fromChainEIP1559Compliant && root.fromChainNoPriorityFee)
                            label: qsTr("Priority fee")
                            labelIcon: "info"
                            labelIconColor: Theme.palette.baseColor1
                            labelIconClickable: true
                            bottomLabelMessageLeftCmp.color: customPriorityFeeInput.displayHigherThanBaseFeeWarning
                                                             || customPriorityFeeInput.displayHigherPriorityFeeWarning?
                                                                 Theme.palette.miscColor6
                                                               : Theme.palette.baseColor1
                            bottomLabelMessageLeftCmp.text: customPriorityFeeInput.displayHigherThanBaseFeeWarning?
                                                                qsTr("Higher than max base fee: %1").arg(customBaseFeeOrGasPriceInput.text)
                                                              : customPriorityFeeInput.displayHigherPriorityFeeWarning?
                                                                    qsTr("Higher than necessary (current %1 - %2)").arg(root.fnGetPriceInNativeTokenForFee(root.currentSuggestedMinPriorityFee).toUpperCase()).arg(root.fnGetPriceInNativeTokenForFee(root.currentSuggestedMaxPriorityFee).toUpperCase())
                                                                  : qsTr("Current: %1 - %2").arg(root.fnGetPriceInNativeTokenForFee(root.currentSuggestedMinPriorityFee).toUpperCase()).arg(root.fnGetPriceInNativeTokenForFee(root.currentSuggestedMaxPriorityFee).toUpperCase())
                            rightPadding: leftPadding
                            input.rightComponent: StatusBaseText {
                                text: "GWEI"
                                color: Theme.palette.baseColor1
                            }

                            validators: [
                                StatusRegularExpressionValidator {
                                    regularExpression: Constants.regularExpressions.positiveRealNumbers
                                    errorMessage: Constants.errorMessages.positiveRealNumbers
                                }
                            ]

                            onTextChanged: Qt.callLater(() => {
                                                            if (!customPriorityFeeInput.valid) {
                                                                return
                                                            }
                                                            d.recalculateCustomPriorityFeePrice()
                                                            d.recalculateCustomPrice()
                                                        })

                            onLabelIconClicked: d.showAlert(label,
                                                            qsTr("AKA miner tip. A voluntary fee you can add to incentivise miners or validators to prioritise your transaction.\n\nThe higher the tip, the faster your transaction is likely to be processed, especially curing periods of higher network congestion.\n"),
                                                            qsTr("Note: the %1 amount shown for this value is calculated: Priority fee (in GWEI) * Max gas amount").arg(root.nativeTokenSymbol),
                                                            "")
                        }

                        StatusInput {
                            id: customGasAmountInput

                            readonly property bool displayTooLowAmountWarning: {
                                if (!customGasAmountInput.text) {
                                    return false
                                }
                                const minValue = SQUtils.AmountsArithmetic.fromString(Constants.minGasForTx)
                                const enteredValue = SQUtils.AmountsArithmetic.fromString(customGasAmountInput.text)
                                return minValue.cmp(enteredValue) === 1
                            }

                            readonly property bool displayTooHighAmountWarning: {
                                if (!customGasAmountInput.text) {
                                    return false
                                }
                                const maxValue = SQUtils.AmountsArithmetic.fromString(Constants.maxGasForTx)
                                const enteredValue = SQUtils.AmountsArithmetic.fromString(customGasAmountInput.text)
                                return enteredValue.cmp(maxValue) === 1
                            }

                            Layout.preferredWidth: parent.width
                            label: qsTr("Max gas amount")
                            labelIcon: "info"
                            labelIconColor: Theme.palette.baseColor1
                            labelIconClickable: true
                            bottomLabelMessageLeftCmp.color: customGasAmountInput.displayTooLowAmountWarning
                                                             || customGasAmountInput.displayTooHighAmountWarning?
                                                                 Theme.palette.dangerColor1
                                                               : Theme.palette.baseColor1
                            bottomLabelMessageLeftCmp.text: customGasAmountInput.displayTooLowAmountWarning?
                                                                qsTr("Too low (should be between %1 and %2)").arg(Constants.minGasForTx).arg(Constants.maxGasForTx)
                                                              : customGasAmountInput.displayTooHighAmountWarning?
                                                                    qsTr("Too high (should be between %1 and %2)").arg(Constants.minGasForTx).arg(Constants.maxGasForTx)
                                                                  : qsTr("Current: %1").arg(root.currentGasAmount)
                            rightPadding: leftPadding
                            input.rightComponent: StatusBaseText {
                                text: qsTr("UNITS")
                                color: Theme.palette.baseColor1
                            }

                            validators: [
                                StatusRegularExpressionValidator {
                                    regularExpression: Constants.regularExpressions.wholeNumbers
                                    errorMessage: Constants.errorMessages.wholeNumbers
                                }
                            ]

                            onTextChanged: Qt.callLater(() => {
                                                            if (!customGasAmountInput.valid) {
                                                                return
                                                            }
                                                            d.recalculatecustomBaseFeeOrGasPricePrice()
                                                            d.recalculateCustomPriorityFeePrice()
                                                            d.recalculateCustomPrice()
                                                        })

                            onLabelIconClicked: d.showAlert(qsTr("Gas amount"),
                                                            qsTr("AKA gas limit. Refers to the maximum number of computational steps (or units of gas) that a transaction can consume. It represents the complexity or amount of work required to execute a transaction or smart contract.\n\nThe gas limit is a cap on how much work the transaction can do on the blockchain. If the gas limit is set too low, the transaction may fail due to insufficient gas."),
                                                            "",
                                                            "")
                        }

                        StatusInput {
                            id: customNonceInput

                            readonly property bool displayHighNonceWarning: {
                                if (!customNonceInput.text) {
                                    return false
                                }

                                try {
                                    const expectedValue = parseInt(root.currentNonce)
                                    const enteredValue = parseInt(customNonceInput.text)
                                    return enteredValue > expectedValue

                                } catch (e) {
                                    return false
                                }
                            }

                            Layout.preferredWidth: parent.width
                            label: qsTr("Nonce")
                            labelIcon: "info"
                            labelIconColor: Theme.palette.baseColor1
                            labelIconClickable: true
                            bottomLabelMessageLeftCmp.color: customNonceInput.displayHighNonceWarning?
                                                                 Theme.palette.miscColor6
                                                               : Theme.palette.baseColor1
                            bottomLabelMessageLeftCmp.text: {
                                if (customNonceInput.displayHighNonceWarning) {
                                    return qsTr("Higher than suggested nonce of %1").arg(root.currentNonce)
                                }
                                let lastUsedNonce = root.currentNonce - 1
                                if (lastUsedNonce < 0) {
                                    lastUsedNonce = "-"
                                }
                                return qsTr("Last transaction: %1").arg(lastUsedNonce)
                            }
                            rightPadding: leftPadding
                            input.leftComponent: input.rightComponent // for the reference to the `input`

                            validators: [
                                StatusRegularExpressionValidator {
                                    regularExpression: Constants.regularExpressions.wholeNumbers
                                    errorMessage: Constants.errorMessages.wholeNumbers
                                }
                            ]

                            onLabelIconClicked: d.showAlert(label,
                                                            qsTr("Transaction counter ensuring transactions from your account are processed in the correct order and can’t be replayed. Each new transaction increments the nonce by 1, ensuring uniqueness and preventing double-spending.\n\nIf a transaction with a lower nonce is pending, higher nonce transactions will remain in the queue until the earlier one is confirmed."),
                                                            "",
                                                            "")
                        }
                    }
                }

                StatusButton {
                    Layout.preferredWidth: parent.width
                    enabled: !d.customMode
                             || (!customBaseFeeOrGasPriceInput.input.dirty || customBaseFeeOrGasPriceInput.valid) &&
                             (!root.fromChainEIP1559Compliant || !customPriorityFeeInput.input.dirty || customPriorityFeeInput.valid) &&
                             (!customGasAmountInput.input.dirty || customGasAmountInput.valid) &&
                             (!customNonceInput.input.dirty || customNonceInput.valid) &&
                             !customGasAmountInput.displayTooHighAmountWarning &&
                             !customGasAmountInput.displayTooLowAmountWarning
                    text: qsTr("Confirm")
                    onClicked: root.confirmClicked()
                }
            }
        }
    }
}
