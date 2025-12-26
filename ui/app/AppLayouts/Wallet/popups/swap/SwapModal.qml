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
    required property int loginType

    signal addMetricsEvent(string subEvent)

    objectName: "swapModal"

    implicitWidth: 556
    fillHeightOnBottomSheet: true
    topPadding: Theme.xlPadding
    backgroundColor: Theme.palette.baseColor3

    QtObject {
        id: d

        readonly property string mandatoryKeysSeparator: "$$"

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

        function rebuildGroupsForChain(chainId) {
            if (chainId <= 0) {
                return
            }

            const listOfTokenKeysAvailableForSwapViaParaswap = root.swapAdaptor.walletAssetsStore.walletTokensStore.getListOfTokenKeysAvailableForSwapViaParaswap(chainId)
            if (listOfTokenKeysAvailableForSwapViaParaswap.length === 0) {
                console.warn("swap via paraswap not supported for chain", chainId)
                const networkName = Utils.getNetworkName(chainId)
                Global.openInfoPopup(qsTr("Info"), qsTr("Swap on %1 is not supported by ParaSwap.").arg(networkName))

                Qt.callLater(() => {
                                 // by default set ethereum chain
                                 root.swapInputParamsForm.selectedNetworkChainId = Utils.isChainIDTestnet(chainId)?
                                     Constants.chains.sepoliaChainId
                                   : Constants.chains.mainnetChainId
                             })
                return
            }
            payPanel.listOfTokenKeysAvailableForSwapViaParaswap = listOfTokenKeysAvailableForSwapViaParaswap
            receivePanel.listOfTokenKeysAvailableForSwapViaParaswap = listOfTokenKeysAvailableForSwapViaParaswap

            const keys = SQUtils.ModelUtils.joinModelEntries(root.swapAdaptor.walletAssetsStore.groupedAccountAssetsModel, "key", d.mandatoryKeysSeparator)
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(chainId, keys)
        }
    }

    ModelEntry {
        id: selectedAccountEntry
        sourceModel: d.accountsSelectorAdaptor.processedWalletAccounts
        key: "address"
        value: root.swapInputParamsForm.selectedAccountAddress
    }

    Connections {
        target: root.swapInputParamsForm
        function onFormValuesChanged() {
            d.fetchSuggestedRoutes()
        }

        function onSelectedNetworkChainIdChanged() {
            d.rebuildGroupsForChain(root.swapInputParamsForm.selectedNetworkChainId)

            networkFilter.selection = [root.swapInputParamsForm.selectedNetworkChainId]
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
        payPanel.reset()
        receivePanel.reset()

        d.rebuildGroupsForChain(root.swapInputParamsForm.selectedNetworkChainId)
    }

    onOpened: {
        payPanel.forceActiveFocus()
        root.addMetricsEvent("popup opened")
    }
    onClosed: {
        root.swapAdaptor.resetData()
        root.addMetricsEvent("popup closed")
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

            // without this Column, the whole popup resizing when the network selector popup is clicked
            Column {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    width: parent.width
                    spacing: 12
                    HeaderTitleText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        text: qsTr("Swap")
                    }
                    StatusBaseText {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        text: qsTr("On:")
                        color: Theme.palette.baseColor1
                        font.pixelSize: Theme.additionalTextSize
                        lineHeight: 38
                        lineHeightMode: Text.FixedHeight
                        verticalAlignment: Text.AlignVCenter
                    }
                    NetworkFilter {
                        id: networkFilter
                        objectName: "networkFilter"
                        Layout.alignment: Qt.AlignVCenter
                        multiSelection: false
                        showSelectionIndicator: false
                        showTitle: false
                        flatNetworks: root.swapAdaptor.networksStore.activeNetworks
                        selection: [root.swapInputParamsForm.selectedNetworkChainId]
                        onSelectionChanged: {
                            root.swapInputParamsForm.selectedNetworkChainId = selection[0]
                            payPanel.forceActiveFocus()
                        }
                    }
                }
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
                    processedAssetsModel: root.swapAdaptor.walletAssetsStore.groupedAccountAssetsModel
                    allTokenGroupsForChainModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsForChainModel
                    searchResultModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.searchResultModel

                    groupKey: root.swapInputParamsForm.fromGroupKey
                    defaultGroupKey: root.swapInputParamsForm.defaultFromGroupKey
                    oppositeSideGroupKey: root.swapInputParamsForm.toGroupKey
                    tokenAmount: root.swapInputParamsForm.fromTokenAmount

                    cryptoFeesToReserve: root.swapAdaptor.swapOutputData.maxFeesToReserveRaw

                    selectedNetworkChainId: root.swapInputParamsForm.selectedNetworkChainId

                    selectedAccountAddress: root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: receivePanel.selectedHoldingId

                    swapSide: SwapInputPanel.SwapSide.Pay
                    swapExchangeButtonWidth: swapExchangeButton.width

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
                    processedAssetsModel: root.swapAdaptor.walletAssetsStore.groupedAccountAssetsModel
                    allTokenGroupsForChainModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsForChainModel
                    searchResultModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.searchResultModel

                    groupKey: root.swapInputParamsForm.toGroupKey
                    defaultGroupKey: root.swapInputParamsForm.defaultToGroupKey
                    oppositeSideGroupKey: root.swapInputParamsForm.fromGroupKey
                    tokenAmount: root.swapAdaptor.validSwapProposalReceived && root.swapAdaptor.toToken ? root.swapAdaptor.swapOutputData.toTokenAmount: root.swapInputParamsForm.toTokenAmount

                    selectedNetworkChainId: root.swapInputParamsForm.selectedNetworkChainId

                    selectedAccountAddress: root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: payPanel.selectedHoldingId

                    swapSide: SwapInputPanel.SwapSide.Receive
                    swapExchangeButtonWidth: swapExchangeButton.width

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
                readonly property string price: root.swapAdaptor.currencyStore.getFiatValue(1, lhsSymbol)

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
                buttonVisible: visible && (root.swapAdaptor.isTokenBalanceInsufficient || root.swapAdaptor.isEthBalanceInsufficient)
                onButtonClicked: {
                    // value dont update correctly if not done from here
                    d.buyFormData.selectedWalletAddress = root.swapInputParamsForm.selectedAccountAddress
                    d.buyFormData.selectedNetworkChainId = root.swapInputParamsForm.selectedNetworkChainId
                    d.buyFormData.selectedTokenKey = root.swapAdaptor.isTokenBalanceInsufficient ?
                                root.swapInputParamsForm.fromGroupKey :
                                d.nativeTokenSymbol
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
                    icon.name: !!d.selectedAccount && d.selectedAccount.migratedToKeycard ? Constants.authenticationIconByType[Constants.LoginType.Keycard]
                                                                                  : Constants.authenticationIconByType[root.loginType]
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
                            root.addMetricsEvent("next button pressed")
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

            loginType: !!d.selectedAccount && d.selectedAccount.migratedToKeycard ? Constants.LoginType.Keycard : root.loginType
            feesLoading: root.swapAdaptor.swapProposalLoading

            fromTokenSymbol: root.swapAdaptor.fromToken.symbol
            fromTokenAmount: root.swapInputParamsForm.fromTokenAmount
            fromTokenContractAddress: {
                let selectedGroup = SQUtils.ModelUtils.getByKey(payPanel.tokenGroupsModel,
                                                                "key",
                                                                root.swapAdaptor.swapFormData.fromGroupKey)
                if (!selectedGroup.tokens) {
                    return ""
                }

                let tokenAddress = SQUtils.ModelUtils.getByKey(selectedGroup.tokens,
                                                               "chainId",
                                                               root.swapInputParamsForm.selectedNetworkChainId,
                                                               "address")
                return tokenAddress
            }

            accountName: d.selectedAccount.name
            accountAddress: d.selectedAccount.address
            accountEmoji: d.selectedAccount.emoji
            accountColor: Utils.getColorForId(Theme.palette, d.selectedAccount.colorId)
            accountBalanceFormatted: d.selectedAccount.accountBalance.formattedBalance

            networkShortName: networkFilter.singleSelectionItemData.shortName
            networkName: networkFilter.singleSelectionItemData.chainName
            networkIconPath: Assets.svg(networkFilter.singleSelectionItemData.iconUrl)
            networkBlockExplorerUrl: networkFilter.singleSelectionItemData.blockExplorerURL
            networkChainId: networkFilter.singleSelectionItemData.chainId

            fiatFees: root.swapAdaptor.currencyStore.formatCurrencyAmount(root.swapAdaptor.swapOutputData.approvalTxFeesFiat, root.swapAdaptor.currencyStore.currentCurrency)

            cryptoFees: {
                const cryptoValue = Utils.nativeTokenRawToDecimal(root.swapInputParamsForm.selectedNetworkChainId, root.swapAdaptor.swapOutputData.approvalTxFeesWei).toString()
                return root.swapAdaptor.currencyStore.formatCurrencyAmount(cryptoValue, d.nativeTokenSymbol)
            }

            estimatedTime: root.swapAdaptor.swapOutputData.estimatedTime

            serviceProviderName: Constants.swap.paraswapName
            serviceProviderURL: Constants.swap.paraswapUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderTandCUrl: Constants.swap.paraswapTermsAndConditionUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderIcon: Assets.png("swap/%1".arg(Constants.swap.paraswapIcon)) // FIXME svg
            serviceProviderContractAddress: root.swapAdaptor.swapOutputData.approvalContractAddress
            serviceProviderHostname: Constants.swap.paraswapHostname

            onRejected: root.addMetricsEvent("rejected approve")
            onAccepted: {
                root.addMetricsEvent("send approve tx")
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

            loginType: !!d.selectedAccount && d.selectedAccount.migratedToKeycard ? Constants.LoginType.Keycard : root.loginType
            feesLoading: root.swapAdaptor.swapProposalLoading

            fromTokenSymbol: root.swapAdaptor.fromToken.symbol
            fromTokenAmount: root.swapInputParamsForm.fromTokenAmount
            fromTokenContractAddress: {
                let selectedGroup = SQUtils.ModelUtils.getByKey(payPanel.tokenGroupsModel,
                                                                "key",
                                                                root.swapAdaptor.swapFormData.fromGroupKey)
                if (!selectedGroup.tokens) {
                    return ""
                }

                let tokenAddress = SQUtils.ModelUtils.getByKey(selectedGroup.tokens,
                                                               "chainId",
                                                               root.swapInputParamsForm.selectedNetworkChainId,
                                                               "address")
                return tokenAddress
            }

            toTokenSymbol: root.swapAdaptor.toToken.symbol
            toTokenAmount: root.swapAdaptor.swapOutputData.toTokenAmount
            toTokenContractAddress: {
                let selectedGroup = SQUtils.ModelUtils.getByKey(receivePanel.tokenGroupsModel,
                                                                "key",
                                                                root.swapAdaptor.swapFormData.toGroupKey)
                if (!selectedGroup.tokens) {
                    return ""
                }

                let tokenAddress = SQUtils.ModelUtils.getByKey(selectedGroup.tokens,
                                                               "chainId",
                                                               root.swapInputParamsForm.selectedNetworkChainId,
                                                               "address")
                return tokenAddress
            }

            accountName: d.selectedAccount.name
            accountAddress: d.selectedAccount.address
            accountEmoji: d.selectedAccount.emoji
            accountColor: Utils.getColorForId(Theme.palette, d.selectedAccount.colorId)

            networkShortName: networkFilter.singleSelectionItemData.shortName
            networkName: networkFilter.singleSelectionItemData.chainName
            networkIconPath: Assets.svg(networkFilter.singleSelectionItemData.iconUrl)
            networkBlockExplorerUrl: networkFilter.singleSelectionItemData.blockExplorerURL
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

            serviceProviderName: Constants.swap.paraswapName
            serviceProviderURL: Constants.swap.paraswapUrl // TODO https://github.com/status-im/status-app/issues/15329
            serviceProviderTandCUrl: Constants.swap.paraswapTermsAndConditionUrl // TODO https://github.com/status-im/status-app/issues/15329

            onRejected: root.addMetricsEvent("rejected sign")
            onAccepted: {
                root.addMetricsEvent("send swap tx")
                root.swapAdaptor.sendSwapTx()
                root.close()
            }
        }
    }
}
