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
import shared.controls

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
    // below; owned/popular/search rows are fed by the producer. May be null while
    // the owning modal defers picker creation until it has opened; the bindings
    // below tolerate that, and this re-initialises once a model arrives.
    required property var tokenSelectorModel
    // SwapModal rebinds this between the swap and swap-to models when the
    // same-chain check flips, so the titles must follow the instance, not just
    // this panel's chain.
    onTokenSelectorModelChanged: {
        if (root.tokenSelectorModel) {
            root.updateSectionNames()
            root.reevaluateSelectedId()
        }
    }

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
    property bool tokenSelectorLoading
    property bool interactive: true

    signal networkSelected(int chainId)

    /** chain the token list is filtered by; -1 = All, independent of this side's chain **/
    property int listChainFilter: -1
    onListChainFilterChanged: root.updateSectionNames()

    /** chain whose token catalog the list shows; this side's chain while on "All" **/
    readonly property int listCatalogChainId: listChainFilter !== -1 ? listChainFilter
                                                                     : selectedNetworkChainId

    property string accountName
    property string accountEmoji
    property string accountColorId
    signal accountPillClicked()

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

    readonly property double maxCryptoBalance: d.maxCryptoBalance
    readonly property double maxSafeCryptoValue: d.maxSafeCryptoValue

    function setAmount(value) {
        if (value > 0)
            amountToSendInput.setValue(SQUtils.AmountsArithmetic.fromNumber(value).toString())
        else
            amountToSendInput.clear()
    }

    // visual properties
    property int swapExchangeButtonWidth: 44

    function forceActiveFocus() {
        amountToSendInput.forceActiveFocus()
    }

    function reset() {
        if (root.tokenSelectorModel)
            root.tokenSelectorModel.search("")
    }

    Binding {
        target: root.tokenSelectorModel
        property: "enabledChainId"
        value: root.listChainFilter
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
        const chainName = root.listChainFilter === -1 ? "" : SQUtils.ModelUtils.getByKey(
            root.flatNetworksModel, "chainId", root.listChainFilter, "chainName") || ""
        root.tokenSelectorModel.setSectionNames(
            !chainName ? qsTr("Your assets") : qsTr("Your assets on %1").arg(chainName),
            qsTr("Popular assets"))
    }
    Component.onCompleted: root.updateSectionNames()

    enum SwapSide {
        Pay = 0,
        Receive = 1
    }

    padding: Theme.padding

    // by design
    implicitWidth: 492
    implicitHeight: 138

    QtObject {
        id: d

        property string selectedHoldingId: root.groupKey
        property string selectedHoldingTokenKey: ""

        onSelectedHoldingIdChanged: Qt.callLater(d.clampAmountToBalance)

        function clampAmountToBalance() {
            if (root.swapSide !== SwapInputPanel.SwapSide.Pay)
                return
            if (d.maxSafeCryptoValue <= 0)
                return
            if (amountToSendInput.balanceExceeded)
                root.setAmount(d.maxSafeCryptoValue)
        }

        function reevaluateSelectedId() {
            if (!root.tokenSelectorModel)
                return
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
            if (!root.tokenSelectorModel)
                return
            if (selectedHolding.available && !!selectedHolding.item) {
                if (!selectedHolding.item.tokens || selectedHolding.item.tokens.ModelCount.count !== 1) {
                    console.error("token for the selected group cannot be resolved", "group-key", d.selectedHoldingId, "chain", root.selectedNetworkChainId)
                    return
                }

                d.selectedHoldingTokenKey = SQUtils.ModelUtils.get(selectedHolding.item.tokens, 0, "key")

                holdingSelector.setSelection(selectedHolding.item.symbol,
                                             selectedHolding.item.logoUri || Constants.tokenIcon(selectedHolding.item.symbol),
                                             selectedHolding.item.key)
                return
            }
            // The terminal model swaps its rows to the search results while searching,
            // so the selected token may not be present then; keep the current button
            // rather than resetting it (it is restored once the search is cleared).
            if (root.tokenSelectorModel.searchString === "")
                holdingSelector.reset()
        }

        readonly property bool isSelectedHoldingValidAsset: selectedHolding.available && !!selectedHolding.item
        readonly property double maxCryptoBalance: {
            if (!isSelectedHoldingValidAsset || !selectedHolding.item.balances)
                return 0
            const onChain = SQUtils.ModelUtils.getByKey(selectedHolding.item.balances, "chainId",
                                                        root.selectedNetworkChainId, "balance")
            return onChain ?? 0
        }
        readonly property double maxFiatBalance:
            maxCryptoBalance * (isSelectedHoldingValidAsset ? (selectedHolding.item.cryptoPrice ?? 0) : 0)
        readonly property double maxInputBalance: amountToSendInput.fiatMode ? maxFiatBalance : maxCryptoBalance
        readonly property string inputSymbol: amountToSendInput.fiatMode ? root.currencyStore.currentCurrency
                                                                         : (!!isSelectedHoldingValidAsset ? selectedHolding.item.symbol : "")
        readonly property string balanceSymbol: isSelectedHoldingValidAsset ? selectedHolding.item.symbol : ""
        readonly property double maxSafeCryptoValue: WalletUtils.calculateMaxSafeSendAmount(maxCryptoBalance, balanceSymbol, root.selectedNetworkChainId, root.cryptoFeesToReserve)


        function adoptChainForToken(key) {
            const balances = SQUtils.ModelUtils.getByKey(root.tokenSelectorModel, "key", key, "balances")
            if (!balances)
                return
            if (SQUtils.ModelUtils.contains(balances, "chainId", root.selectedNetworkChainId))
                return
            const firstChain = SQUtils.ModelUtils.get(balances, 0, "chainId")
            if (!!firstChain && firstChain !== root.selectedNetworkChainId)
                root.networkSelected(firstChain)
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
            let currentInputTextAmount = SQUtils.AmountsArithmetic.fromString(amountToSendInput.delocalized).toFixed()
            if (currentInputTextAmount !== amountToSet &&
                    !(amountToSet === "0" && !amountToSendInput.text)) {
                amountToSendInput.setValue(tokenAmount)
            }
        }
    }

    ModelEntry {
        id: networkEntry
        sourceModel: root.flatNetworksModel
        key: "chainId"
        value: root.selectedNetworkChainId
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

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.halfPadding

            AccountSelectorPill {
                objectName: "accountSelectorPill"

                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.maximumWidth: root.width / 2

                name: root.accountName
                emoji: root.accountEmoji
                colorId: root.accountColorId
                address: root.selectedAccountAddress

                onClicked: root.accountPillClicked()
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                objectName: "networkBadge"

                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: Theme.halfPadding
                visible: networkEntry.available

                StatusRoundedImage {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    image.source: !!networkEntry.item && !!networkEntry.item.iconUrl
                                  ? Assets.svg(networkEntry.item.iconUrl) : ""
                }

                StatusBaseText {
                    objectName: "networkBadgeText"
                    Layout.alignment: Qt.AlignVCenter
                    text: !!networkEntry.item ? networkEntry.item.chainName : ""
                    color: Theme.palette.directColor1
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            AmountToSend {
                readonly property bool balanceExceeded:
                    SQUtils.AmountsArithmetic.fromNumber(d.maxSafeCryptoValue, multiplierIndex).cmp(amount) === -1

                readonly property double asNumber: {
                    if (!valid)
                        return 0

                    return parseFloat(delocalized)
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                id: amountToSendInput
                objectName: "amountToSendInput"
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

            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: Theme.halfPadding

                AssetSelector {
                    id: holdingSelector

                    objectName: "holdingSelector"

                    Layout.alignment: Qt.AlignRight

                    model: root.tokenSelectorModel
                    hasMoreItems: !!root.tokenSelectorModel && root.tokenSelectorModel.hasMoreItems
                    isLoadingMore: root.tokenSelectorLoading || (!!root.tokenSelectorModel && root.tokenSelectorModel.isLoadingMore)
                    nonInteractiveKey: root.nonInteractiveGroupKey
                    formatCurrencyBalance: (amount) => root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency)

                    selectedNetworkIcon: !!networkEntry.item && !!networkEntry.item.iconUrl
                                         ? Assets.svg(networkEntry.item.iconUrl) : ""
                    defaultNetworkIcon: !!networkEntry.item ? (networkEntry.item.iconUrl ?? "") : ""

                    flatNetworksModel: root.flatNetworksModel
                    selectedChainId: root.listChainFilter
                    highlightedChainId: root.selectedNetworkChainId
                    onChainSelected: chainId => root.listChainFilter = chainId

                    onSearch: function(keyword) {
                        if (root.tokenSelectorModel)
                            root.tokenSelectorModel.search(keyword)
                    }

                    onLoadMoreRequested: {
                        if (root.tokenSelectorModel)
                            root.tokenSelectorModel.fetchMore()
                    }

                    onSelected: function(key, chainId) {
                        if (key === "")
                            return
                        d.selectedHoldingId = key
                        if (chainId !== -1)
                            root.networkSelected(chainId)
                        else if (root.listChainFilter !== -1)
                            root.networkSelected(root.listChainFilter)
                        else
                            d.adoptChainForToken(key)
                    }
                }

                RowLayout {
                    objectName: "balanceLine"
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.halfPadding
                    visible: d.isSelectedHoldingValidAsset

                    StatusIcon {
                        Layout.alignment: Qt.AlignVCenter
                        width: 16
                        height: 16
                        icon: "wallet"
                        color: Theme.palette.directColor5
                    }

                    StatusBaseText {
                        objectName: "balanceCryptoText"
                        text: root.currencyStore.formatCurrencyAmount(
                                  d.maxCryptoBalance, d.balanceSymbol,
                                  { noSymbol: true, roundingMode: LocaleUtils.RoundingMode.Down })
                        color: Theme.palette.directColor5
                        font.pixelSize: Theme.additionalTextSize
                        font.weight: Font.Medium
                    }

                    StatusBaseText {
                        text: "|"
                        color: Theme.palette.directColor7
                        font.pixelSize: Theme.additionalTextSize
                    }

                    StatusBaseText {
                        objectName: "balanceFiatText"
                        text: root.currencyStore.formatCurrencyAmount(
                                  d.maxFiatBalance, root.currencyStore.currentCurrency)
                        color: Theme.palette.directColor5
                        font.pixelSize: Theme.additionalTextSize
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
