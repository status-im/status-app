import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

import AppLayouts.Wallet
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.stores

import shared.popups.send.views

import utils
import shared.stores

import QtModelsToolkit
import SortFilterProxyModel

Control {
    id: root

    // input API
    required property CurrenciesStore currencyStore
    required property var flatNetworksModel

    // Terminal picker model (swap/all-tokens), created by the caller from the
    // token-selector producer. Its per-modal params are driven by the bindings
    // below; owned/popular/search rows are fed by the producer.
    required property var tokenSelectorModel
    // SwapModal rebinds this between the swap and swap-to models when the
    // same-chain check flips, so the titles must follow the instance, not just
    // this panel's chain.
    onTokenSelectorModelChanged: root.updateSectionNames()

    property int selectedNetworkChainId: -1
    onSelectedNetworkChainIdChanged: {
        reevaluateSelectedId()
        root.updateSectionNames()
    }
    property string selectedAccountAddress
    onSelectedAccountAddressChanged: reevaluateSelectedId()
    property string nonInteractiveGroupKey

    property string groupKey
    onGroupKeyChanged: {
        d.selectedHoldingId = groupKey
        reevaluateSelectedId()
    }

    property string defaultGroupKey
    property string oppositeSideGroupKey

    property string tokenAmount
    onTokenAmountChanged: Qt.callLater(d.updateInputText) // FIXME remove the callLater(), shouldn't be needed now

    property real cryptoFeesToReserve: 0

    property int swapSide: SwapInputPanel.SwapSide.Pay
    property bool fiatInputInteractive
    property bool mainInputLoading
    property bool bottomTextLoading
    property bool tokenSelectorLoading
    property bool interactive: true

    // shows a network selector next to the asset selector to change this side's chain
    property bool showNetworkSelector: false
    signal networkSelected(int chainId)

    function reevaluateSelectedId() {
        // Ensure calculation after all bindings are evaluated
        Qt.callLater(d.reevaluateSelectedId)
    }

    // output API
    readonly property string selectedHoldingId: d.selectedHoldingId
    readonly property string selectedHoldingTokenKey: d.selectedHoldingTokenKey

    readonly property double value: amountToSendInput.asNumber
    readonly property string rawValue: {
        if (!d.isSelectedHoldingValidAsset) {
            return "0"
        }
        return amountToSendInput.amount
    }
    readonly property int rawValueMultiplierIndex: amountToSendInput.multiplierIndex
    readonly property bool valueValid: value > 0 && amountToSendInput.valid &&
                                       (swapSide === SwapInputPanel.SwapSide.Pay ? !amountEnteredGreaterThanBalance : true)
    readonly property bool amountEnteredGreaterThanBalance: amountToSendInput.balanceExceeded

    // visual properties
    property int swapExchangeButtonWidth: 44
    property string caption: swapSide === SwapInputPanel.SwapSide.Pay ? qsTr("Pay") : qsTr("Receive")

    function forceActiveFocus() {
        amountToSendInput.forceActiveFocus()
    }

    function reset() {
        root.tokenSelectorModel.search("")
    }

    // Drive the picker model's per-panel params (swap = all-tokens; -1 chain = no
    // filter, matching the retired adaptor's empty enabledChainIds).
    Binding {
        target: root.tokenSelectorModel
        property: "enabledChainId"
        value: root.selectedNetworkChainId
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root.tokenSelectorModel
        property: "accountAddress"
        value: root.selectedAccountAddress
        restoreMode: Binding.RestoreNone
    }
    function updateSectionNames() {
        if (!root.tokenSelectorModel)
            return
        const chainName = SQUtils.ModelUtils.getByKey(
            root.flatNetworksModel, "chainId", root.selectedNetworkChainId, "chainName") || ""
        root.tokenSelectorModel.setSectionNames(
            qsTr("Your assets on %1").arg(chainName), qsTr("Popular assets"))
    }
    Component.onCompleted: root.updateSectionNames()

    enum SwapSide {
        Pay = 0,
        Receive = 1
    }

    padding: Theme.padding

    // by design
    implicitWidth: 492
    implicitHeight: 131

    QtObject {
        id: d

        property string selectedHoldingId: root.groupKey
        property string selectedHoldingTokenKey: ""

        function reevaluateSelectedId() {
            const entry = SQUtils.ModelUtils.getByKey(root.tokenSelectorModel, "key", d.selectedHoldingId)
            if (!entry) {
                // Token doesn't exist in destination chain
                d.selectedHoldingId = root.defaultGroupKey
            }
        }


        readonly property var selectedHolding: ModelEntry {
            sourceModel: root.tokenSelectorModel
            key: "key"
            value: d.selectedHoldingId
            onValueChanged: d.setHoldingToSelector()
            onAvailableChanged: d.setHoldingToSelector()
        }

        function setHoldingToSelector() {
            if (selectedHolding.available && !!selectedHolding.item) {
                if (!selectedHolding.item.tokens || selectedHolding.item.tokens.ModelCount.count !== 1) {
                    console.error("token for the selected group cannot be resolved", "group-key", d.selectedHoldingId, "chain", root.selectedNetworkChainId)
                    return
                }

                d.selectedHoldingTokenKey = SQUtils.ModelUtils.get(selectedHolding.item.tokens, 0, "key")

                holdingSelector.setSelection(selectedHolding.item.symbol, selectedHolding.item.logoUri, selectedHolding.item.key)
                return
            }
            // The terminal model swaps its rows to the search results while searching,
            // so the selected token may not be present then; keep the current button
            // rather than resetting it (it is restored once the search is cleared).
            if (root.tokenSelectorModel.searchString === "")
                holdingSelector.reset()
        }

        readonly property bool isSelectedHoldingValidAsset: selectedHolding.available && !!selectedHolding.item
        readonly property double maxFiatBalance: isSelectedHoldingValidAsset && !!selectedHolding.item.currencyBalance ? selectedHolding.item.currencyBalance : 0
        readonly property double maxCryptoBalance: isSelectedHoldingValidAsset && !!selectedHolding.item.currentBalance ? selectedHolding.item.currentBalance : 0
        readonly property double maxInputBalance: amountToSendInput.fiatMode ? maxFiatBalance : maxCryptoBalance
        readonly property string inputSymbol: amountToSendInput.fiatMode ? root.currencyStore.currentCurrency
                                                                         : (!!isSelectedHoldingValidAsset ? selectedHolding.item.symbol : "")


        function updateInputText() {
            if (!tokenAmount) {
                amountToSendInput.clear()
                return
            }
            let amountToSet = SQUtils.AmountsArithmetic.fromString(tokenAmount).toFixed()
            /* When deleting characters after a decimal point
            eg: 0.000001 being deleted we have 0.00000 and it should not be updated to 0
            and thats why we compare with toFixed()
            also when deleting a numbers last digit, we should not update the text to 0
            instead it should remain empty as entered by the user */
            let currentInputTextAmount = SQUtils.AmountsArithmetic.fromString(amountToSendInput.delocalized).toFixed()
            if (currentInputTextAmount !== amountToSet &&
                    !(amountToSet === "0" && !amountToSendInput.text)) {
                amountToSendInput.setValue(tokenAmount)
            }
        }
    }

    background: Shape {
        id: shape

        property int radius: root.Theme.radius
        property int leftTopRadius: radius
        property int rightTopRadius: radius
        property int leftBottomRadius: radius
        property int rightBottomRadius: radius

        readonly property int cutoutGap: 4

        scale: swapSide === SwapInputPanel.SwapSide.Pay ? -1 : 1

        ShapePath {
            id: path
            fillColor: root.Theme.palette.indirectColor3
            strokeColor: amountToSendInput.cursorVisible ? root.Theme.palette.directColor7 : root.Theme.palette.directColor8
            strokeWidth: 1
            capStyle: ShapePath.RoundCap

            startX: shape.leftTopRadius
            startY: 0

            PathLine {
                x: shape.width/2 - root.swapExchangeButtonWidth/2 - (shape.cutoutGap/2 + path.strokeWidth)
                y: 0
            }
            PathArc { // the cutout
                relativeX: root.swapExchangeButtonWidth + (shape.cutoutGap + path.strokeWidth*2)
                direction: PathArc.Counterclockwise
                radiusX: root.swapExchangeButtonWidth/2 + path.strokeWidth
                radiusY: root.swapExchangeButtonWidth/2 - path.strokeWidth/2
            }
            PathLine {
                x: shape.width - shape.rightTopRadius
                y: 0
            }

            PathArc {
                x: shape.width
                y: shape.rightTopRadius
                radiusX: shape.rightTopRadius
                radiusY: shape.rightTopRadius
            }
            PathLine {
                x: shape.width
                y: shape.height - shape.rightBottomRadius
            }
            PathArc {
                x: shape.width - shape.rightBottomRadius
                y: shape.height
                radiusX: shape.rightBottomRadius
                radiusY: shape.rightBottomRadius
            }
            PathLine {
                x: shape.leftBottomRadius
                y: shape.height
            }
            PathArc {
                x: 0
                y: shape.height - shape.leftBottomRadius
                radiusX: shape.leftBottomRadius
                radiusY: shape.leftBottomRadius
            }
            PathLine {
                x: 0
                y: shape.leftTopRadius
            }
            PathArc {
                x: shape.leftTopRadius
                y: 0
                radiusX: shape.leftTopRadius
                radiusY: shape.leftTopRadius
            }
        }
    }

    contentItem: RowLayout {
        spacing: 20
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true

            AmountToSend {
                readonly property bool balanceExceeded:
                    SQUtils.AmountsArithmetic.fromNumber(maxSendButton.maxSafeCryptoValue, multiplierIndex).cmp(amount) === -1

                readonly property double asNumber: {
                    if (!valid)
                        return 0

                    return parseFloat(delocalized)
                }

                Layout.fillWidth: true
                id: amountToSendInput
                objectName: "amountToSendInput"
                caption: root.caption
                interactive: root.interactive
                markAsInvalid: (root.swapSide === SwapInputPanel.SwapSide.Pay && (balanceExceeded || d.maxInputBalance === 0)) || (!!text && !valid)
                fiatInputInteractive: root.fiatInputInteractive
                multiplierIndex: d.isSelectedHoldingValidAsset && !!d.selectedHolding.item.decimals ? d.selectedHolding.item.decimals : 18
                cryptoPrice: d.isSelectedHoldingValidAsset && !!d.selectedHolding.item.cryptoPrice ? d.selectedHolding.item.cryptoPrice : 0
                formatFiat: amount => root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency)
                formatBalance: amount => root.currencyStore.formatCurrencyAmount(amount, d.inputSymbol)

                mainInputLoading: root.mainInputLoading
                bottomTextLoading: root.bottomTextLoading
            }
        }
        ColumnLayout {

            NetworkFilter {
                id: networkSelector
                objectName: "networkFilter"

                Layout.alignment: Qt.AlignRight
                visible: root.showNetworkSelector

                multiSelection: false
                showSelectionIndicator: false
                showTitle: false
                flatNetworks: root.flatNetworksModel
                // bound so an unset (-1) chain stays unset (no auto-select); guard below emits only on a real pick
                selection: [root.selectedNetworkChainId]
                onSelectionChanged: {
                    if (selection.length > 0 && selection[0] !== root.selectedNetworkChainId)
                        root.networkSelected(selection[0])
                }
            }

            Item { Layout.fillHeight: true }

            AssetSelector {
                id: holdingSelector

                objectName: "holdingSelector"

                Layout.alignment: Qt.AlignRight

                model: root.tokenSelectorModel
                hasMoreItems: root.tokenSelectorModel.hasMoreItems
                isLoadingMore: root.tokenSelectorLoading || root.tokenSelectorModel.isLoadingMore
                nonInteractiveKey: root.nonInteractiveGroupKey
                formatCurrencyBalance: (amount) => root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency)

                onSearch: function(keyword) {
                    root.tokenSelectorModel.search(keyword)
                }

                onLoadMoreRequested: root.tokenSelectorModel.fetchMore()

                onSelected: function(key) {
                    // Token existance checked with plainTokensBySymbolModel
                    // This check prevents resetting selection when chain is changed until
                    // processedAssetsModel is updated
                    if (key !== "") {
                        d.selectedHoldingId = key
                    }
                }
            }

            Item { Layout.fillHeight: !maxSendButton.visible }

            MaxSendButton {
                id: maxSendButton

                Layout.alignment: Qt.AlignRight
                objectName: "maxTagButton"

                readonly property double maxSafeValue: WalletUtils.calculateMaxSafeSendAmount(d.maxInputBalance, d.inputSymbol, root.selectedNetworkChainId, root.cryptoFeesToReserve)
                readonly property double maxSafeCryptoValue: WalletUtils.calculateMaxSafeSendAmount(d.maxCryptoBalance, d.inputSymbol, root.selectedNetworkChainId, root.cryptoFeesToReserve)

                markAsInvalid: amountToSendInput.markAsInvalid

                formattedValue: d.maxInputBalance === 0 ? LocaleUtils.userInputLocale.zeroDigit
                                                        : root.currencyStore.formatCurrencyAmount(
                                                              maxSafeValue, d.inputSymbol,
                                                              { noSymbol: !amountToSendInput.fiatMode,
                                                                roundingMode: LocaleUtils.RoundingMode.Down })

                visible: d.isSelectedHoldingValidAsset && root.swapSide === SwapInputPanel.SwapSide.Pay

                onClicked: function() {
                    if (maxSafeValue)
                        amountToSendInput.setValue(SQUtils.AmountsArithmetic.fromNumber(maxSafeValue).toString())
                    else
                        amountToSendInput.clear()
                    root.forceActiveFocus()
                }
            }
        }
    }
}
