import QtQuick
import QtQuick.Layouts
import QtQml.Models

import QtModelsToolkit
import SortFilterProxyModel

import utils

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import shared.popups.send.controls
import shared.controls
import shared.panels

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.adaptors

StatusDialog {
    id: root

    /* This should be the only property which should be used to input
    parameters to the modal when being launched from elsewhere */
    required property SwapInputParamsForm swapInputParamsForm
    required property SwapModalAdaptor swapAdaptor

    /** input property to indicate if buy action is enabled **/
    property bool buyEnabled

    objectName: "swapModal"

    Component.onDestruction: {
        const store = root.swapAdaptor.walletAssetsStore.walletTokensStore
        if (d.payTokenSelector)
            store.releaseTokenSelectorModel(d.payTokenSelector.id)
        if (d.receiveTokenSelector)
            store.releaseTokenSelectorModel(d.receiveTokenSelector.id)
        if (d.receiveTokenSelectorTo)
            store.releaseTokenSelectorModel(d.receiveTokenSelectorTo.id)
    }

    implicitWidth: 556
    fillHeightOnBottomSheet: true
    topPadding: Theme.xlPadding
    backgroundColor: Theme.palette.baseColor3

    QtObject {
        id: d

        readonly property string mandatoryKeysSeparator: "$$"

        property int lastRequestedChainId: -1
        property int lastRequestedChainIdTo: -1

        property var payTokenSelector: null
        property var receiveTokenSelector: null
        property var receiveTokenSelectorTo: null

        property bool pickersInitialized: false

        function createPickers() {
            const store = root.swapAdaptor.walletAssetsStore.walletTokensStore
            if (!d.payTokenSelector) {
                d.payTokenSelector = store.createTokenSelectorModel(1)
                d.receiveTokenSelector = store.createTokenSelectorModel(1)
            }
            d.pickersInitialized = true
            if (d.isBridge)
                d.ensureBridgePicker()
            payPanel.reset()
            receivePanel.reset()
        }

        function ensureBridgePicker() {
            if (d.receiveTokenSelectorTo)
                return
            d.receiveTokenSelectorTo = root.swapAdaptor.walletAssetsStore.walletTokensStore.createTokenSelectorModel(3)
            // seed it like createPickers seeds the source-chain ones
            receivePanel.reset()
        }

        property var debounceFetchSuggestedRoutes: Backpressure.debounce(root, 1000, function() {
            root.swapAdaptor.fetchSuggestedRoutes(payPanel.rawValue)
        })

        function fetchSuggestedRoutes() {
            root.swapAdaptor.invalidateSuggestedRoute()
            if (root.swapInputParamsForm.isFormFilledCorrectly()) {
                root.swapAdaptor.swapProposalLoading = true
                debounceFetchSuggestedRoutes()
            } else {
                root.swapAdaptor.swapProposalLoading = false
            }
        }

        readonly property bool isError: root.swapAdaptor.errorMessage !== ""

        readonly property BuyCryptoParamsForm buyFormData: BuyCryptoParamsForm {
            selectedWalletAddress: root.swapInputParamsForm.selectedAccountAddress
            selectedNetworkChainId: root.swapInputParamsForm.selectedNetworkChainId
            selectedTokenGroupKey: root.swapInputParamsForm.fromGroupKey
        }

        readonly property WalletAccountsSelectorAdaptor accountsSelectorAdaptor : WalletAccountsSelectorAdaptor {
            accounts: root.swapAdaptor.swapStore.accounts
            assetsModel: root.swapAdaptor.walletAssetsStore.baseGroupedAccountAssetModel
            tokenGroupsModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel
            filteredFlatNetworksModel: root.swapAdaptor.networksStore.activeNetworks

            selectedGroupKey: root.swapInputParamsForm.fromGroupKey
            selectedNetworkChainId: root.swapInputParamsForm.selectedNetworkChainId

            fnFormatCurrencyAmountFromBigInt: function(balance, symbol, decimals, options = null) {
                return root.swapAdaptor.currencyStore.formatCurrencyAmountFromBigInt(balance, symbol, decimals, options)
            }
        }

        readonly property var selectedAccount: selectedAccountEntry.item

        readonly property int loadingFeesWidth: 60

        readonly property string nativeTokenSymbol: Utils.getNativeTokenSymbol(root.swapInputParamsForm.selectedNetworkChainId)

        // same chain => plain swap (from/to token must differ); different chains => bridge (same token ok)
        readonly property bool isSameChainSwap: root.swapInputParamsForm.selectedNetworkChainId === root.swapInputParamsForm.toNetworkChainId
        readonly property bool isBridge: root.swapInputParamsForm.toNetworkChainId !== -1 && !isSameChainSwap
        onIsBridgeChanged: {
            // `opened` also excludes teardown: the handler resets the form one
            // field at a time, which flickers through a bridge state that would
            // otherwise build a picker for the modal being destroyed.
            if (isBridge && d.pickersInitialized && root.opened)
                d.ensureBridgePicker()
        }

        readonly property bool swapViaLiFi: root.swapAdaptor.swapOutputData.txProviderName === Constants.swap.lifiProcessorName
        readonly property string serviceProviderName: d.swapViaLiFi ? Constants.swap.lifiName : Constants.swap.paraswapName
        readonly property string serviceProviderUrl: d.swapViaLiFi ? Constants.swap.lifiUrl : Constants.swap.paraswapUrl
        readonly property string serviceProviderTandCUrl: d.swapViaLiFi ? Constants.swap.lifiTermsAndConditionUrl : Constants.swap.paraswapTermsAndConditionUrl
        readonly property string serviceProviderHostname: d.swapViaLiFi ? Constants.swap.lifiHostname : Constants.swap.paraswapHostname
        readonly property string serviceProviderIconName: d.swapViaLiFi ? Constants.swap.lifiIcon : Constants.swap.paraswapIcon

        function rebuildGroupsForChain(chainId, isToSide = false) {
            if (chainId <= 0) {
                return
            }

            // Skip the redundant harvest + async fetch when this side's chain hasn't
            // changed (Component.onCompleted + the chain-changed handler both fire for
            // the same chain on open). Tracked per side; reset on close.
            if (isToSide) {
                if (chainId === d.lastRequestedChainIdTo)
                    return
            } else if (chainId === d.lastRequestedChainId) {
                return
            }

            const walletTokensStore = root.swapAdaptor.walletAssetsStore.walletTokensStore
            const chainAvailableForSwap = walletTokensStore.isChainSupportedForSwapViaParaswap(chainId)
                                       || walletTokensStore.isChainSupportedForSwapViaLiFi(chainId)
            if (!chainAvailableForSwap) {
                console.warn("swap not supported for chain", chainId)
                const networkName = Utils.getNetworkName(chainId)
                Global.openInfoPopup(qsTr("Info"), qsTr("Swaps on %1 are coming soon.").arg(networkName))

                Qt.callLater(() => {
                                 if (isToSide) {
                                     root.swapInputParamsForm.toNetworkChainId = root.swapInputParamsForm.selectedNetworkChainId
                                     return
                                 }
                                 // by default set ethereum chain
                                 root.swapInputParamsForm.selectedNetworkChainId = Utils.isChainIDTestnet(chainId)?
                                     Constants.chains.hoodiChainId
                                   : Constants.chains.mainnetChainId
                             })
                return
            }

            if (isToSide)
                d.lastRequestedChainIdTo = chainId
            else
                d.lastRequestedChainId = chainId
            const keys = SQUtils.ModelUtils.joinModelEntries(root.swapAdaptor.walletAssetsStore.groupedAccountAssetsModel, "key", d.mandatoryKeysSeparator)
            if (isToSide)
                walletTokensStore.buildGroupsForChainTo(chainId, keys)
            else
                walletTokensStore.buildGroupsForChain(chainId, keys)
        }
    }

    ModelEntry {
        id: selectedAccountEntry
        sourceModel: d.accountsSelectorAdaptor.processedWalletAccounts
        key: "address"
        value: root.swapInputParamsForm.selectedAccountAddress
    }

    // source (pay) network data for the approve/sign modals (tx executes on the source chain)
    ModelEntry {
        id: fromNetworkEntry
        sourceModel: root.swapAdaptor.networksStore.activeNetworks
        key: "chainId"
        value: root.swapInputParamsForm.selectedNetworkChainId
    }

    Connections {
        target: root.swapInputParamsForm
        function onFormValuesChanged() {
            d.fetchSuggestedRoutes()
        }

        // the two chain selectors are independent: each rebuilds only its own catalog
        function onSelectedNetworkChainIdChanged() {
            d.rebuildGroupsForChain(root.swapInputParamsForm.selectedNetworkChainId)
        }

        function onToNetworkChainIdChanged() {
            // only bridging needs a separate destination catalog; a same-chain receive reuses the source
            if (d.isBridge)
                d.rebuildGroupsForChain(root.swapInputParamsForm.toNetworkChainId, true)
        }

        function onFromGroupKeyChanged() {
            payPanel.groupKey = root.swapInputParamsForm.fromGroupKey
        }

        function onToGroupKeyChanged() {
            receivePanel.groupKey = root.swapInputParamsForm.toGroupKey
        }
    }

    // needed as the first time the value not loaded correctly without this Binding
    Binding {
        target: root.swapAdaptor
        property: "amountEnteredGreaterThanBalance"
        value: payPanel.amountEnteredGreaterThanBalance
    }

    Component.onCompleted: {
        d.rebuildGroupsForChain(root.swapInputParamsForm.selectedNetworkChainId)
        if (d.isBridge)
            d.rebuildGroupsForChain(root.swapInputParamsForm.toNetworkChainId, true)
    }

    onOpened: {
        // Defer the terminal picker model creation + seed off the open critical
        // path; callLater lets the opened frame render before the seed runs.
        Qt.callLater(d.createPickers)
        payPanel.forceActiveFocus()
    }
    onClosed: {
        d.lastRequestedChainId = -1
        d.lastRequestedChainIdTo = -1
        root.swapAdaptor.resetData()
    }

    header: Item {
        AccountSelectorHeader {
            y: -height - Theme.padding
            control.popup.width: 512
            model: d.accountsSelectorAdaptor.processedWalletAccounts
            selectedAddress: root.swapInputParamsForm.selectedAccountAddress
            onCurrentAccountAddressChanged: {
                if (currentAccountAddress !== "" && currentAccountAddress !== root.swapInputParamsForm.selectedAccountAddress) {
                    root.swapInputParamsForm.selectedAccountAddress = currentAccountAddress
                }
            }
            control.popup.onClosed: payPanel.forceActiveFocus()
        }
    }

    StatusScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        topPadding: 0
        bottomPadding: Theme.xlPadding

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.padding
            clip: true

            HeaderTitleText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                text: qsTr("Swap")
            }

            Item {
                Layout.fillWidth: true
                Layout.margins: 2
                Layout.preferredHeight: payPanel.height + receivePanel.height + 4

                SwapInputPanel {
                    id: payPanel
                    objectName: "payPanel"

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }

                    currencyStore: root.swapAdaptor.currencyStore
                    flatNetworksModel: root.swapAdaptor.networksStore.activeNetworks
                    // null until the deferred createPickers runs post-open
                    tokenSelectorModel: d.payTokenSelector ? d.payTokenSelector.model : null

                    groupKey: root.swapInputParamsForm.fromGroupKey
                    defaultGroupKey: root.swapInputParamsForm.defaultFromGroupKey
                    oppositeSideGroupKey: root.swapInputParamsForm.toGroupKey
                    tokenAmount: root.swapInputParamsForm.fromTokenAmount

                    cryptoFeesToReserve: root.swapAdaptor.swapOutputData.maxFeesToReserveRaw

                    selectedNetworkChainId: root.swapInputParamsForm.selectedNetworkChainId
                    showNetworkSelector: true
                    onNetworkSelected: function(chainId) {
                        root.swapInputParamsForm.selectedNetworkChainId = chainId
                        payPanel.forceActiveFocus()
                    }

                    selectedAccountAddress: root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: d.isSameChainSwap ? receivePanel.selectedHoldingId : ""

                    swapSide: SwapInputPanel.SwapSide.Pay
                    swapExchangeButtonWidth: swapExchangeButton.width

                    tokenSelectorLoading: root.swapAdaptor.walletAssetsStore.walletTokensStore.groupsForChainLoading
                    bottomTextLoading: root.swapAdaptor.swapProposalLoading

                    onSelectedHoldingIdChanged: root.swapInputParamsForm.fromGroupKey = selectedHoldingId

                    onRawValueChanged: {
                        if(root.swapInputParamsForm.fromGroupKey === selectedHoldingId) {
                            const zero = SQUtils.AmountsArithmetic.fromString("0")
                            const bigIntRawValue = SQUtils.AmountsArithmetic.fromString(rawValue)
                            const amount = !tokenAmount && SQUtils.AmountsArithmetic.cmp(bigIntRawValue, zero) === 0 ? "" :
                                                                         SQUtils.AmountsArithmetic.div(bigIntRawValue,
                                                                                                       SQUtils.AmountsArithmetic.fromNumber(1, rawValueMultiplierIndex)).toString()
                            root.swapInputParamsForm.fromTokenAmount = amount
                        }
                    }
                }

                SwapInputPanel {
                    id: receivePanel
                    objectName: "receivePanel"

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    currencyStore: root.swapAdaptor.currencyStore
                    flatNetworksModel: root.swapAdaptor.networksStore.activeNetworks
                    // plain swap reuses the source-chain picker; only a bridge uses the destination one
                    // (both null until the deferred createPickers/ensureBridgePicker run post-open)
                    tokenSelectorModel: {
                        if (d.isSameChainSwap)
                            return d.receiveTokenSelector ? d.receiveTokenSelector.model : null
                        return d.receiveTokenSelectorTo ? d.receiveTokenSelectorTo.model : null
                    }

                    groupKey: root.swapInputParamsForm.toGroupKey
                    defaultGroupKey: root.swapInputParamsForm.defaultToGroupKey
                    oppositeSideGroupKey: root.swapInputParamsForm.fromGroupKey
                    tokenAmount: root.swapAdaptor.validSwapProposalReceived && root.swapAdaptor.toToken ? root.swapAdaptor.swapOutputData.toTokenAmount: root.swapInputParamsForm.toTokenAmount

                    selectedNetworkChainId: root.swapInputParamsForm.toNetworkChainId
                    showNetworkSelector: true
                    onNetworkSelected: function(chainId) {
                        root.swapInputParamsForm.toNetworkChainId = chainId
                        payPanel.forceActiveFocus()
                    }

                    selectedAccountAddress: root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: d.isSameChainSwap ? payPanel.selectedHoldingId : ""

                    swapSide: SwapInputPanel.SwapSide.Receive
                    swapExchangeButtonWidth: swapExchangeButton.width

                    tokenSelectorLoading: d.isSameChainSwap
                        ? root.swapAdaptor.walletAssetsStore.walletTokensStore.groupsForChainLoading
                        : root.swapAdaptor.walletAssetsStore.walletTokensStore.groupsForChainToLoading
                    mainInputLoading: root.swapAdaptor.swapProposalLoading
                    bottomTextLoading: root.swapAdaptor.swapProposalLoading

                    onSelectedHoldingIdChanged: root.swapInputParamsForm.toGroupKey = selectedHoldingId

                    /* TODO: keep this input as disabled until the work for adding a param to handle to
                    and from tokens inputed is supported by backend under
                    https://github.com/status-im/status-app/issues/15095 */
                    interactive: false
                }

                SwapExchangeButton {
                    id: swapExchangeButton
                    objectName: "swapExchangeButton"
                    anchors.centerIn: parent
                    enabled: !!root.swapInputParamsForm.fromGroupKey || !!root.swapInputParamsForm.toGroupKey
                    onClicked: {
                        const tempPayToken = root.swapInputParamsForm.fromGroupKey
                        const tempPayAmount = root.swapInputParamsForm.fromTokenAmount
                        // also swap the chains so the bridge direction is inverted
                        const tempFromChain = root.swapInputParamsForm.selectedNetworkChainId
                        root.swapInputParamsForm.selectedNetworkChainId = root.swapInputParamsForm.toNetworkChainId
                        root.swapInputParamsForm.toNetworkChainId = tempFromChain
                        root.swapInputParamsForm.fromGroupKey = root.swapInputParamsForm.toGroupKey
                        root.swapInputParamsForm.fromTokenAmount = !!root.swapAdaptor.swapOutputData.toTokenAmount ? root.swapAdaptor.swapOutputData.toTokenAmount : root.swapInputParamsForm.toTokenAmount
                        root.swapInputParamsForm.toGroupKey = tempPayToken
                        root.swapInputParamsForm.toTokenAmount = tempPayAmount
                        payPanel.forceActiveFocus()
                    }
                }
            }

            RowLayout {
                id: approximationRow
                property bool inversedOrder: false
                readonly property SwapInputPanel leftPanel: inversedOrder ? receivePanel : payPanel
                readonly property SwapInputPanel rightPanel: inversedOrder ? payPanel : receivePanel

                readonly property string lhsSymbol: leftPanel.groupKey ?? ""
                readonly property double lhsAmount: leftPanel.value
                readonly property string rhsSymbol: rightPanel.groupKey ?? ""
                readonly property double rhsAmount: rightPanel.value
                readonly property int rhsDecimals: rightPanel.rawValueMultiplierIndex
                readonly property bool amountLoading: receivePanel.mainInputLoading || payPanel.mainInputLoading

                readonly property string quote: !!lhsAmount && !!rhsAmount ? SQUtils.AmountsArithmetic.div(
                                                    SQUtils.AmountsArithmetic.fromNumber(rhsAmount),
                                                    SQUtils.AmountsArithmetic.fromNumber(lhsAmount)).toFixed(rhsDecimals) : 1

                readonly property string price: root.swapAdaptor.currencyStore.getFiatValue(1, leftPanel.selectedHoldingTokenKey)

                function formatCurrency(amount, symbol) {
                    return root.swapAdaptor.currencyStore.formatCurrencyAmount(amount, symbol,
                                                                            { roundingMode: LocaleUtils.RoundingMode.Down, stripTrailingZeroes: true })
                }

                visible: root.swapAdaptor.validSwapProposalReceived || root.swapAdaptor.swapProposalLoading
                spacing: 0

                onVisibleChanged: inversedOrder = false // restore to default
                onAmountLoadingChanged: inversedOrder = false // restore to default

                StatusBaseText {
                    objectName: "quoteApproximationLeft"
                    text: "%1 ≈ ".arg(approximationRow.formatCurrency(1, approximationRow.lhsSymbol))

                    color: Theme.palette.directColor4
                    font {
                        weight: Font.Medium
                        pixelSize: Theme.additionalTextSize
                    }
                }

                StatusTextWithLoadingState {
                    Layout.preferredWidth: loading ? 40 : implicitWidth
                    objectName: "quoteApproximationRight"
                    text: "%1 ".arg(approximationRow.formatCurrency(approximationRow.quote, approximationRow.rhsSymbol))

                    customColor: Theme.palette.directColor4
                    font {
                        weight: Font.Medium
                        pixelSize: Theme.additionalTextSize
                    }
                    loading: approximationRow.amountLoading
                }

                StatusBaseText {
                    id: quoteApproximation
                    objectName: "quoteApproximationPrice"
                    text: "(%1)".arg(approximationRow.formatCurrency(
                                            approximationRow.price,
                                            root.swapAdaptor.currencyStore.currentCurrency
                                            ))

                    color: Theme.palette.directColor5
                    font {
                        weight: Font.Medium
                        pixelSize: Theme.additionalTextSize
                    }
                    visible: !approximationRow.amountLoading
                }

                StatusFlatButton {
                    objectName: "invertQuoteApproximation"
                    icon.name: "swap"
                    size: StatusBaseButton.Size.XSmall
                    onClicked: approximationRow.inversedOrder = !approximationRow.inversedOrder
                    hoverColor: "transparent"
                    textColor: hovered ? Theme.palette.directColor4 : Theme.palette.directColor5
                    visible: !approximationRow.amountLoading
                }
            }

            EditSlippagePanel {
                id: editSlippagePanel
                objectName: "editSlippagePanel"
                Layout.fillWidth: true
                Layout.topMargin: Theme.padding
                visible: editSlippageButton.checked
                selectedToToken: root.swapAdaptor.toToken
                toTokenAmount: root.swapAdaptor.swapOutputData.toTokenAmount
                loading: root.swapAdaptor.swapProposalLoading
                onSlippageValueChanged: {
                    root.swapInputParamsForm.selectedSlippage = slippageValue
                }
            }

            ErrorTag {
                objectName: "errorTag"
                visible: d.isError
                Layout.maximumWidth: parent.width
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.smallPadding
                text: root.swapAdaptor.errorMessage
                buttonText: root.swapAdaptor.isTokenBalanceInsufficient ? qsTr("Add assets") : qsTr("Add %1").arg(d.nativeTokenSymbol)
                buttonVisible: visible && (root.swapAdaptor.isTokenBalanceInsufficient || root.swapAdaptor.isEthBalanceInsufficient) && root.buyEnabled
                onButtonClicked: {
                    // value dont update correctly if not done from here
                    d.buyFormData.selectedWalletAddress = root.swapInputParamsForm.selectedAccountAddress
                    d.buyFormData.selectedNetworkChainId = root.swapInputParamsForm.selectedNetworkChainId
                    d.buyFormData.selectedTokenGroupKey = root.swapAdaptor.isTokenBalanceInsufficient ?
                                root.swapInputParamsForm.fromGroupKey :
                                Utils.getNativeTokenGroupKey(root.swapInputParamsForm.selectedNetworkChainId)
                    Global.openBuyCryptoModalRequested(d.buyFormData)
                }
            }
        }
    }

    footer: StatusDialogFooter {
        color: Theme.palette.baseColor3
        dropShadowEnabled: true
        leftButtons: ObjectModel {
            ColumnLayout {
                Layout.leftMargin: Theme.padding
                spacing: 0
                StatusBaseText {
                    objectName: "maxSlippageText"
                    text: qsTr("Max slippage:")
                    color: Theme.palette.directColor5
                    font.weight: Font.Medium
                }
                RowLayout {
                    StatusBaseText {
                        objectName: "maxSlippageValue"
                        text: editSlippagePanel.valid ? "%1%".arg(LocaleUtils.numberToLocaleString(root.swapInputParamsForm.selectedSlippage))
                                                      : qsTr("N/A")
                        color: Theme.palette.directColor4
                        font.weight: Font.Medium
                    }
                    StatusFlatButton {
                        id: editSlippageButton
                        objectName: "editSlippageButton"
                        checkable: true
                        checked: false
                        icon.name: "edit_pencil"
                        textColor: editSlippageButton.hovered ? Theme.palette.directColor1 : Theme.palette.directColor5
                        size: StatusBaseButton.Size.Tiny
                        hoverColor: StatusColors.transparent
                        visible: !checked
                    }
                }
            }
        }
        rightButtons: ObjectModel {
            RowLayout {
                Layout.rightMargin: Theme.padding
                spacing: Theme.bigPadding
                ColumnLayout {
                    StatusBaseText {
                        objectName: "maxFeesText"
                        text: qsTr("Max fees:")
                        color: Theme.palette.directColor5
                        font.weight: Font.Medium
                    }
                    StatusBaseText {
                        id: fees
                        objectName: "maxFeesValue"
                        text: {
                            if(root.swapAdaptor.swapProposalLoading) {
                                return ""
                            }

                            if(root.swapAdaptor.validSwapProposalReceived) {
                                let fees = root.swapAdaptor.swapOutputData.txFeesInFiat
                                if(root.swapAdaptor.swapOutputData.approvalNeeded && !root.swapAdaptor.approvalSuccessful) {
                                    fees = root.swapAdaptor.swapOutputData.approvalTxFeesFiat
                                }
                                return root.swapAdaptor.currencyStore.formatCurrencyAmount(fees, root.swapAdaptor.currencyStore.currentCurrency)
                            }

                            return "--"
                        }

                        onTextChanged: function(text) {
                            if (text === "" || text === "--") {
                                animation.stop()
                                return
                            }
                            animation.restart()
                        }

                        color: Theme.palette.directColor4
                        font.weight: Font.Medium

                        StatusColorAnimation {
                            id: animation
                            target: fees
                        }

                        LoadingComponent {
                            width: d.loadingFeesWidth
                            height: parent.font.pixelSize
                            visible: root.swapAdaptor.swapProposalLoading
                        }
                    }
                }
                StatusButton {
                    objectName: "signButton"
                    readonly property string fromTokenSymbol: !!root.swapAdaptor.fromToken ? root.swapAdaptor.fromToken.symbol ?? "" : ""
                    loadingWithText: root.swapAdaptor.approvalPending
                    icon.name: Utils.resolveAuthSignIcon(!!d.selectedAccount ? d.selectedAccount.keyUid : "",
                                                         !!d.selectedAccount && d.selectedAccount.migratedToColdWallet,
                                                         Constants.AuthSignPurpose.General)
                    text: {
                        if(root.swapAdaptor.validSwapProposalReceived) {
                            if(root.swapAdaptor.swapOutputData.approvalNeeded) {
                                if (root.swapAdaptor.approvalPending) {
                                    return qsTr("Approving %1").arg(fromTokenSymbol)
                                } else if(!root.swapAdaptor.approvalSuccessful) {
                                    return qsTr("Approve %1").arg(fromTokenSymbol)
                                }
                            }
                        }
                        return qsTr("Swap")
                    }
                    tooltip.text: {
                        if(root.swapAdaptor.validSwapProposalReceived) {
                            if(root.swapAdaptor.swapOutputData.approvalNeeded) {
                                if (root.swapAdaptor.approvalPending) {
                                    return qsTr("Approving %1 spending cap to Swap").arg(fromTokenSymbol)
                                } else if(!root.swapAdaptor.approvalSuccessful) {
                                    return qsTr("Approve %1 spending cap to Swap").arg(fromTokenSymbol)
                                }
                            }
                        }
                        return ""
                    }
                    disabledColor: Theme.palette.directColor8
                    interactive: root.swapAdaptor.validSwapProposalReceived &&
                                 editSlippagePanel.valid &&
                                 !d.isError &&
                                 !root.swapAdaptor.approvalPending
                    onClicked: {
                        if (root.swapAdaptor.validSwapProposalReceived) {
                            if (root.swapAdaptor.swapOutputData.approvalNeeded && !root.swapAdaptor.approvalSuccessful)
                                Global.openPopup(swapApproveModalComponent)
                            else
                                Global.openPopup(swapSignModalComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: swapApproveModalComponent
        SwapApproveCapModal {
            destroyOnClose: true

            formatBigNumber: (number, symbol, noSymbolOption) => root.swapAdaptor.currencyStore.formatBigNumber(number, symbol, noSymbolOption)

            keyUid: !!d.selectedAccount ? d.selectedAccount.keyUid : ""
            migratedToColdWallet: !!d.selectedAccount && d.selectedAccount.migratedToColdWallet
            feesLoading: root.swapAdaptor.swapProposalLoading

            fromTokenSymbol: root.swapAdaptor.fromToken.symbol
            fromTokenAmount: root.swapInputParamsForm.fromTokenAmount
            fromTokenContractAddress: {
                let details = Utils.getChainAndAddressFromTokenKey(payPanel.selectedHoldingTokenKey)
                return details.address
            }

            accountName: d.selectedAccount.name
            accountAddress: d.selectedAccount.address
            accountEmoji: d.selectedAccount.emoji
            accountColor: Utils.getColorForId(Theme.palette, d.selectedAccount.colorId)
            accountBalanceFormatted: d.selectedAccount.accountBalance.formattedBalance

            networkShortName: fromNetworkEntry.item.shortName
            networkName: fromNetworkEntry.item.chainName
            networkIconPath: Assets.svg(fromNetworkEntry.item.iconUrl)
            networkBlockExplorerUrl: fromNetworkEntry.item.blockExplorerURL
            networkChainId: fromNetworkEntry.item.chainId

            fiatFees: root.swapAdaptor.currencyStore.formatCurrencyAmount(root.swapAdaptor.swapOutputData.approvalTxFeesFiat, root.swapAdaptor.currencyStore.currentCurrency)

            cryptoFees: {
                const cryptoValue = Utils.nativeTokenRawToDecimal(root.swapInputParamsForm.selectedNetworkChainId, root.swapAdaptor.swapOutputData.approvalTxFeesWei).toString()
                return root.swapAdaptor.currencyStore.formatCurrencyAmount(cryptoValue, d.nativeTokenSymbol)
            }

            estimatedTime: root.swapAdaptor.swapOutputData.estimatedTime

            serviceProviderName: d.serviceProviderName
            serviceProviderURL: d.serviceProviderUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderTandCUrl: d.serviceProviderTandCUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderIcon: Assets.png("swap/%1".arg(d.serviceProviderIconName)) // FIXME svg
            serviceProviderContractAddress: root.swapAdaptor.swapOutputData.approvalContractAddress
            serviceProviderHostname: d.serviceProviderHostname

            onAccepted: {
                root.swapAdaptor.sendApproveTx()
            }
        }
    }

    Component {
        id: swapSignModalComponent
        SwapSignModal {
            destroyOnClose: true

            title: root.swapAdaptor.swapOutputData.approvalNeeded && root.swapAdaptor.approvalSuccessful? qsTr("Swap") : qsTr("Sign Swap")
            signButtonText: root.swapAdaptor.swapOutputData.approvalNeeded && root.swapAdaptor.approvalSuccessful? qsTr("Swap") : qsTr("Sign")

            formatBigNumber: (number, symbol, noSymbolOption) => root.swapAdaptor.currencyStore.formatBigNumber(number, symbol, noSymbolOption)

            keyUid: !!d.selectedAccount ? d.selectedAccount.keyUid : ""
            migratedToColdWallet: !!d.selectedAccount && d.selectedAccount.migratedToColdWallet
            feesLoading: root.swapAdaptor.swapProposalLoading

            fromTokenSymbol: root.swapAdaptor.fromToken.symbol
            fromTokenAmount: root.swapInputParamsForm.fromTokenAmount
            fromTokenContractAddress: {
                let details = Utils.getChainAndAddressFromTokenKey(payPanel.selectedHoldingTokenKey)
                return details.address
            }

            toTokenSymbol: root.swapAdaptor.toToken.symbol
            toTokenAmount: root.swapAdaptor.swapOutputData.toTokenAmount
            toTokenContractAddress: {
                let details = Utils.getChainAndAddressFromTokenKey(receivePanel.selectedHoldingTokenKey)
                return details.address
            }

            accountName: d.selectedAccount.name
            accountAddress: d.selectedAccount.address
            accountEmoji: d.selectedAccount.emoji
            accountColor: Utils.getColorForId(Theme.palette, d.selectedAccount.colorId)

            networkShortName: fromNetworkEntry.item.shortName
            networkName: fromNetworkEntry.item.chainName
            networkIconPath: Assets.svg(fromNetworkEntry.item.iconUrl)
            networkBlockExplorerUrl: fromNetworkEntry.item.blockExplorerURL
            networkChainId: root.swapInputParamsForm.selectedNetworkChainId

            fiatFees: {
                let fees = root.swapAdaptor.swapOutputData.txFeesInFiat
                if(root.swapAdaptor.swapOutputData.approvalNeeded && !root.swapAdaptor.approvalSuccessful) {
                    fees = root.swapAdaptor.swapOutputData.approvalTxFeesFiat
                }
                return root.swapAdaptor.currencyStore.formatCurrencyAmount(fees, root.swapAdaptor.currencyStore.currentCurrency)
            }

            cryptoFees: {
                let cryptoValue = Utils.nativeTokenRawToDecimal(root.swapInputParamsForm.selectedNetworkChainId, root.swapAdaptor.swapOutputData.txFeesWei)
                if(root.swapAdaptor.swapOutputData.approvalNeeded && !root.swapAdaptor.approvalSuccessful) {
                    cryptoValue = Utils.nativeTokenRawToDecimal(root.swapInputParamsForm.selectedNetworkChainId, root.swapAdaptor.swapOutputData.approvalTxFeesWei).toString()
                }
                return root.swapAdaptor.currencyStore.formatCurrencyAmount(cryptoValue, d.nativeTokenSymbol)
            }

            slippage: root.swapInputParamsForm.selectedSlippage

            serviceProviderName: d.serviceProviderName
            serviceProviderURL: d.serviceProviderUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderTandCUrl: d.serviceProviderTandCUrl // TODO https://github.com/status-im/status-app/issues/15329

            onAccepted: {
                root.swapAdaptor.sendSwapTx()
                root.close()
            }
        }
    }
}
