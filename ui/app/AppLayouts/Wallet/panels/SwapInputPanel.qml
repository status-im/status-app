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
import AppLayouts.Wallet.adaptors

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
    required property var processedAssetsModel

    property var allTokenGroupsForChainModel
    property var searchResultModel
    property var listOfTokenKeysAvailableForSwapViaParaswap

    property int selectedNetworkChainId: -1
    onSelectedNetworkChainIdChanged: reevaluateSelectedId()
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
    property bool interactive: true

    function reevaluateSelectedId() {
        // Ensure calculation after all bindings are evaluated
        Qt.callLater(d.reevaluateSelectedId)
    }

    // output API
    readonly property string selectedHoldingId: d.selectedHoldingId
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
        d.adaptor.search("")
    }

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


        function reevaluateSelectedId() {
            const entry = SQUtils.ModelUtils.getByKey(d.adaptor.outputAssetsModel, "key", d.selectedHoldingId)
            if (!entry) {
                // Token doesn't exist in destination chain
                d.selectedHoldingId = root.defaultGroupKey
            }
        }


        readonly property var selectedHolding: ModelEntry {
            sourceModel: d.adaptor.outputAssetsModel
            key: "key"
            value: d.selectedHoldingId
            onValueChanged: d.setHoldingToSelector()
            onAvailableChanged: d.setHoldingToSelector()
        }

        function setHoldingToSelector() {
            // search in currentlly selected output asset model (full(lazy-loaded) or search)
            if (selectedHolding.available && !!selectedHolding.item) {
                holdingSelector.setSelection(selectedHolding.item.symbol, selectedHolding.item.iconSource, selectedHolding.item.key)
                return
            }
            // search in full model (lazy-loaded items) if not found in selected model (fir example while searching, but the other token is selected)
            const entry = SQUtils.ModelUtils.getByKey(d.adaptor.fullOutputAssetsModel, "key", d.selectedHoldingId)
            if (!!entry) {
                holdingSelector.setSelection(entry.symbol, entry.iconSource, entry.key)
                return
            }
            holdingSelector.reset()
        }

        readonly property bool isSelectedHoldingValidAsset: selectedHolding.available && !!selectedHolding.item
        readonly property double maxFiatBalance: isSelectedHoldingValidAsset && !!selectedHolding.item.currencyBalance ? selectedHolding.item.currencyBalance : 0
        readonly property double maxCryptoBalance: isSelectedHoldingValidAsset && !!selectedHolding.item.currentBalance ? selectedHolding.item.currentBalance : 0
        readonly property double maxInputBalance: amountToSendInput.fiatMode ? maxFiatBalance : maxCryptoBalance
        readonly property string inputSymbol: amountToSendInput.fiatMode ? root.currencyStore.currentCurrency
                                                                         : (!!isSelectedHoldingValidAsset ? selectedHolding.item.symbol : "")

        readonly property var adaptor: TokenSelectorViewAdaptor {
            assetsModel: root.processedAssetsModel
            allTokenGroupsForChainModel: root.allTokenGroupsForChainModel
            searchResultModel: root.searchResultModel
            listOfAvailableTokens: root.listOfTokenKeysAvailableForSwapViaParaswap

            flatNetworksModel: root.flatNetworksModel
            currentCurrency: root.currencyStore.currentCurrency

            showAllTokens: true
            enabledChainIds: root.selectedNetworkChainId !== -1 ? [root.selectedNetworkChainId] : []
            accountAddress: root.selectedAccountAddress
        }

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
            let currentInputTextAmount = SQUtils.AmountsArithmetic.fromString(amountToSendInput.text.replace(amountToSendInput.locale.decimalPoint,'.')).toFixed()
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

                    return parseFloat(text.replace(LocaleUtils.userInputLocale.decimalPoint, "."))
                }

                Layout.fillWidth: true
                id: amountToSendInput
                objectName: "amountToSendInput"
                caption: root.caption
                interactive: root.interactive
                markAsInvalid: (root.swapSide === SwapInputPanel.SwapSide.Pay && (balanceExceeded || d.maxInputBalance === 0)) || (!!text && !valid)
                fiatInputInteractive: root.fiatInputInteractive
                multiplierIndex: d.isSelectedHoldingValidAsset && !!d.selectedHolding.item.decimals ? d.selectedHolding.item.decimals : 18
                cryptoPrice: d.isSelectedHoldingValidAsset ? (!!d.isSelectedHoldingValidAsset && !!d.selectedHolding.item.marketDetails ? d.selectedHolding.item.marketDetails.currencyPrice.amount : 0)
                                                     : 0
                formatFiat: amount => root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency)
                formatBalance: amount => root.currencyStore.formatCurrencyAmount(amount, d.inputSymbol)

                mainInputLoading: root.mainInputLoading
                bottomTextLoading: root.bottomTextLoading
            }
        }
        ColumnLayout {

            Item { Layout.fillHeight: true }

            AssetSelector {
                id: holdingSelector

                objectName: "holdingSelector"

                Layout.alignment: Qt.AlignRight

                model: d.adaptor.outputAssetsModel
                hasMoreItems: d.adaptor.outputAssetsModel.hasMoreItems
                isLoadingMore: d.adaptor.outputAssetsModel.isLoadingMore
                nonInteractiveKey: root.nonInteractiveGroupKey

                onSearch: function(keyword) {
                    d.adaptor.search(keyword)
                }

                onLoadMoreRequested: d.adaptor.loadMoreItems()

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
