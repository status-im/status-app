import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

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

import AppLayouts.Wallet
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.adaptors

StatusDialog {
    id: root

    required property SwapInputParamsForm swapInputParamsForm
    required property SwapModalAdaptor swapAdaptor

    /** input property to indicate if buy action is enabled **/
    property bool buyEnabled

    /** recipient source models for the "Send to" (receive) account selector **/
    property var savedAddressesModel
    property var recentRecipientsModel
    /** resolve an ENS name typed into the receive-side recipient input **/
    property var fnResolveENS: function(ensName, uuid) {}
    signal ensNameResolved(string resolvedPubKey, string resolvedAddress, string uuid)

    objectName: "swapModal"

    Component.onDestruction: {
        const store = root.swapAdaptor.walletAssetsStore.walletTokensStore
        const ids = [d.payTokenSelector, d.receiveTokenSelector, d.receiveTokenSelectorTo]
                        .filter(sel => !!sel).map(sel => sel.id)

        d.payTokenSelector = null
        d.receiveTokenSelector = null
        d.receiveTokenSelectorTo = null

        ids.forEach(id => store.releaseTokenSelectorModel(id))
    }

    implicitWidth: 556
    padding: Theme.smallPadding
    topPadding: Theme.bigPadding
    backgroundColor: Theme.palette.baseColor3

    QtObject {
        id: d

        readonly property string mandatoryKeysSeparator: "$$"

        readonly property int panelMargin: 2 // so the card's shape stroke isn't clipped

        // closePolicy only covers Key_Escape (verified on Qt 6.11), so Android's Back would
        // otherwise bubble to AppMain.tryGoBack(), which knows nothing about open popups, and
        // minimise the app. Attached to both the content and the footer: key events only
        // travel up from the focused item, and the footer is not inside the scroll view.
        function handleBackKey(event) {
            if (event.key !== Qt.Key_Back)
                return
            event.accepted = true
            root.closeHandler()
        }

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
            receivePanel.reset()
        }

        // The chain the destination catalog has to be built for, -1 while there is no
        // bridge picker to fill. Folding both conditions into the value means a pay-side
        // change that turns a plain swap into a bridge triggers the build too, which
        // watching the receive chain alone would miss. rebuildGroupsForChain ignores -1.
        readonly property int toCatalogChainId: d.isBridge && !!d.receiveTokenSelectorTo
                                                ? receivePanel.listCatalogChainId : -1
        onToCatalogChainIdChanged: d.rebuildGroupsForChain(toCatalogChainId, true)

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
            accounts: root.swapAdaptor.accountsModel
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
        readonly property var toAccount: toAccountEntry.item

        readonly property string nativeTokenSymbol: Utils.getNativeTokenSymbol(root.swapInputParamsForm.selectedNetworkChainId)

        readonly property bool isSameChainSwap: root.swapInputParamsForm.selectedNetworkChainId === root.swapInputParamsForm.toNetworkChainId
        readonly property bool isBridge: root.swapInputParamsForm.toNetworkChainId !== -1 && !isSameChainSwap
        onIsBridgeChanged: {
            // `opened` also excludes teardown: the handler resets the form one
            // field at a time, which flickers through a bridge state that would
            // otherwise build a picker for the modal being destroyed.
            if (isBridge && d.pickersInitialized && root.opened)
                d.ensureBridgePicker()
        }

        readonly property string modalTitle: {
            const fromKey = root.swapInputParamsForm.fromGroupKey
            const toKey = root.swapInputParamsForm.toGroupKey
            if (!fromKey || !toKey)
                return qsTr("Swap + Bridge")
            if (!d.isBridge)
                return qsTr("Swap")
            return fromKey === toKey ? qsTr("Bridge") : qsTr("Swap + Bridge")
        }

        readonly property string routeOrderName: {
            switch (root.swapInputParamsForm.selectedRouteOrder) {
            case Constants.swap.routeOrderFastest: return qsTr("Fastest")
            case Constants.swap.routeOrderLowestFee: return qsTr("Lowest fee")
            default: return qsTr("Best return")
            }
        }

        readonly property bool swapViaLiFi: root.swapAdaptor.swapOutputData.txProviderName === Constants.swap.lifiProcessorName
        readonly property string serviceProviderName: d.swapViaLiFi ? Constants.swap.lifiName : Constants.swap.paraswapName
        readonly property string serviceProviderUrl: d.swapViaLiFi ? Constants.swap.lifiUrl : Constants.swap.paraswapUrl
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
            const chainAvailableForSwap = walletTokensStore.isChainSupportedForSwapViaLiFi(chainId)
            if (!chainAvailableForSwap) {
                console.warn("swap not supported for chain", chainId)
                const networkName = Utils.getNetworkName(chainId)
                Global.openInfoPopup(qsTr("Info"), qsTr("Swaps on %1 are coming soon.").arg(networkName))

                const isSideChain = chainId === (isToSide ? root.swapInputParamsForm.toNetworkChainId
                                                          : root.swapInputParamsForm.selectedNetworkChainId)
                if (isSideChain)
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

    ModelEntry {
        id: toAccountEntry
        sourceModel: d.accountsSelectorAdaptor.processedWalletAccounts
        key: "address"
        value: root.swapInputParamsForm.toAccountAddress || root.swapInputParamsForm.selectedAccountAddress
    }

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

        function onSelectedNetworkChainIdChanged() {
            d.rebuildGroupsForChain(payPanel.listCatalogChainId)
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

    // the destination catalog follows d.toCatalogChainId, which is still -1 here
    Component.onCompleted: d.rebuildGroupsForChain(payPanel.listCatalogChainId)

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

    Component {
        id: fromAccountPopupComponent
        SwapFromAccountPopup {
            model: d.accountsSelectorAdaptor.processedWalletAccounts
            selectedAddress: root.swapInputParamsForm.selectedAccountAddress
            onAccountSelected: function(address) {
                root.swapInputParamsForm.selectedAccountAddress = address
            }
            onClosed: payPanel.forceActiveFocus()
        }
    }

    Component {
        id: toAccountPopupComponent
        SwapToAccountPopup {
            id: toAccountPopup
            savedAddressesModel: root.savedAddressesModel
            accountsModel: root.swapAdaptor.accountsModel
            recentRecipientsModel: root.recentRecipientsModel
            fnResolveENS: root.fnResolveENS
            onRecipientSelected: function(address) {
                root.swapInputParamsForm.toAccountAddress = address
            }
            onClosed: payPanel.forceActiveFocus()

            readonly property Connections resolvedEnsConnection: Connections {
                target: root
                function onEnsNameResolved(resolvedPubKey, resolvedAddress, uuid) {
                    toAccountPopup.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
                }
            }
        }
    }

    StatusScrollView {
        id: contentScrollView

        anchors.fill: parent
        contentWidth: availableWidth
        topPadding: 0
        bottomPadding: 0

        focus: true
        Keys.onPressed: event => d.handleBackKey(event)

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.padding
            clip: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.padding

                HeaderTitleText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    text: d.modalTitle
                }

                StatusFlatRoundButton {
                    objectName: "closeButton"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    icon.name: "close"
                    icon.color: Theme.palette.directColor1
                    icon.width: 24
                    icon.height: 24
                    type: StatusFlatRoundButton.Type.Secondary
                    onClicked: root.closeHandler()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.margins: d.panelMargin
                Layout.preferredHeight: payPanel.height + receivePanel.height + Theme.halfPadding

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
                    onNetworkSelected: function(chainId) {
                        root.swapInputParamsForm.selectedNetworkChainId = chainId
                        payPanel.forceActiveFocus()
                    }

                    onListCatalogChainIdChanged: d.rebuildGroupsForChain(listCatalogChainId)
                    catalogChainId: d.lastRequestedChainId

                    selectedAccountAddress: root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: d.isSameChainSwap ? receivePanel.selectedHoldingId : ""

                    accountName: !!d.selectedAccount ? d.selectedAccount.name : ""
                    accountEmoji: !!d.selectedAccount ? d.selectedAccount.emoji : ""
                    accountColorId: !!d.selectedAccount ? d.selectedAccount.colorId : ""
                    onAccountPillClicked: fromAccountPopupComponent.createObject(root).open()

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

                    onFiatModeChanged: receivePanel.setFiatMode(fiatMode)
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
                    onNetworkSelected: function(chainId) {
                        root.swapInputParamsForm.toNetworkChainId = chainId
                        payPanel.forceActiveFocus()
                    }

                    // A plain swap shares the pay side's picker, whose catalog follows
                    // the PAY chain filter — so it can be scoped to a chain this side
                    // knows nothing about.
                    catalogChainId: d.isSameChainSwap ? d.lastRequestedChainId
                                                      : d.lastRequestedChainIdTo

                    onListChainFilterChanged: {
                        if (listChainFilter !== -1)
                            root.swapInputParamsForm.toNetworkChainId = listChainFilter
                    }

                    selectedAccountAddress: root.swapInputParamsForm.toAccountAddress || root.swapInputParamsForm.selectedAccountAddress
                    nonInteractiveGroupKey: d.isSameChainSwap ? payPanel.selectedHoldingId : ""

                    accountName: !!d.toAccount ? d.toAccount.name : ""
                    accountEmoji: !!d.toAccount ? d.toAccount.emoji : ""
                    accountColorId: !!d.toAccount ? d.toAccount.colorId : ""
                    onAccountPillClicked: toAccountPopupComponent.createObject(root).open()

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
                    fiatInputInteractive: false // read-only
                }

                SwapExchangeButton {
                    id: swapExchangeButton
                    objectName: "swapExchangeButton"
                    anchors.centerIn: parent
                    enabled: !!root.swapInputParamsForm.fromGroupKey || !!root.swapInputParamsForm.toGroupKey
                    onClicked: {
                        const tempPayToken = root.swapInputParamsForm.fromGroupKey
                        const tempPayAmount = root.swapInputParamsForm.fromTokenAmount
                        const tempFromChain = root.swapInputParamsForm.selectedNetworkChainId
                        root.swapInputParamsForm.selectedNetworkChainId = root.swapInputParamsForm.toNetworkChainId
                        root.swapInputParamsForm.toNetworkChainId = tempFromChain
                        if (!!root.swapInputParamsForm.toAccountAddress && toAccountEntry.available) {
                            const tempFromAccount = root.swapInputParamsForm.selectedAccountAddress
                            root.swapInputParamsForm.selectedAccountAddress = root.swapInputParamsForm.toAccountAddress
                            root.swapInputParamsForm.toAccountAddress = tempFromAccount
                        }
                        root.swapInputParamsForm.fromGroupKey = root.swapInputParamsForm.toGroupKey
                        root.swapInputParamsForm.fromTokenAmount = !!root.swapAdaptor.swapOutputData.toTokenAmount ? root.swapAdaptor.swapOutputData.toTokenAmount : root.swapInputParamsForm.toTokenAmount
                        root.swapInputParamsForm.toGroupKey = tempPayToken
                        root.swapInputParamsForm.toTokenAmount = tempPayAmount
                        payPanel.forceActiveFocus()
                    }
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

    footer: Control {
        id: swapFooter

        width: root.width
        Keys.onPressed: event => d.handleBackKey(event)

        // match the content inset: dialog padding + scroll view padding + card margin
        horizontalPadding: root.padding + contentScrollView.leftPadding + d.panelMargin
        topPadding: 0
        // StatusDialog only insets the safe area when there's no footer; a custom one must
        // do it itself or the buttons land under the Android navigation bar.
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom

        readonly property bool hasProposal: root.swapAdaptor.validSwapProposalReceived
        readonly property bool loading: root.swapAdaptor.swapProposalLoading

        readonly property int refreshSeconds: Math.max(1, Math.round(root.swapInputParamsForm.autoRefreshTime / 1000))
        property int secondsLeft: refreshSeconds
        // The router re-emits suggestedRoutesReady for a uuid it has already answered, which
        // would otherwise restart the window on a quote that hasn't changed.
        property string countdownUuid: ""
        onCountdownUuidChanged: secondsLeft = refreshSeconds

        property bool quoteInverted: false
        readonly property string fromSym: !!root.swapAdaptor.fromToken ? (root.swapAdaptor.fromToken.symbol ?? "") : ""
        readonly property string toSym: !!root.swapAdaptor.toToken ? (root.swapAdaptor.toToken.symbol ?? "") : ""
        readonly property double fromAmt: parseFloat(root.swapInputParamsForm.fromTokenAmount) || 0
        readonly property double toAmt: parseFloat(root.swapAdaptor.swapOutputData.toTokenAmount) || 0
        readonly property string quoteText: {
            if (!fromAmt || !toAmt || !fromSym || !toSym)
                return ""
            const cs = root.swapAdaptor.currencyStore
            const rate = quoteInverted ? fromAmt / toAmt : toAmt / fromAmt
            const baseSym = quoteInverted ? toSym : fromSym
            const quoteSym = quoteInverted ? fromSym : toSym
            return "1 %1 ≈ %2".arg(baseSym).arg(cs.formatCurrencyAmount(rate, quoteSym))
        }

        function refresh() {
            secondsLeft = refreshSeconds
            d.fetchSuggestedRoutes()
        }

        background: Rectangle {
            color: Theme.palette.baseColor3
        }

        Timer {
            interval: 1000
            repeat: true
            running: swapFooter.hasProposal && !swapFooter.loading && root.visible
            onTriggered: {
                if (swapFooter.secondsLeft <= 1)
                    swapFooter.refresh()
                else
                    swapFooter.secondsLeft--
            }
        }

        Connections {
            target: root.swapAdaptor
            function onValidSwapProposalReceivedChanged() {
                if (root.swapAdaptor.validSwapProposalReceived)
                    swapFooter.countdownUuid = root.swapAdaptor.uuid
            }
        }

        contentItem: ColumnLayout {
            spacing: Theme.padding

            RowLayout {
                id: quoteRow

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Theme.halfPadding
                visible: swapFooter.hasProposal || swapFooter.loading

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    visible: !swapFooter.loading // counts against a quote being replaced

                    StatusCircularProgressBar {
                        anchors.fill: parent
                        size: 28
                        lineWidth: 2
                        animationDuration: 0
                        value: swapFooter.secondsLeft / swapFooter.refreshSeconds
                    }
                    StatusBaseText {
                        anchors.centerIn: parent
                        text: qsTr("%1s", "short for seconds").arg(swapFooter.secondsLeft)
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.palette.primaryColor1
                    }
                }

                StatusTextWithLoadingState {
                    objectName: "swapQuoteText"
                    Layout.fillWidth: true
                    Layout.maximumWidth: loading ? 120 : implicitWidth
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: swapFooter.quoteText
                    customColor: Theme.palette.directColor1
                    font.weight: Font.Medium
                    font.pixelSize: Theme.additionalTextSize
                    loading: swapFooter.loading
                }

                StatusFlatRoundButton {
                    objectName: "invertQuoteButton"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    icon.name: "swap"
                    icon.width: 20
                    icon.height: 20
                    type: StatusFlatRoundButton.Type.Tertiary
                    visible: !swapFooter.loading && !!swapFooter.quoteText
                    onClicked: swapFooter.quoteInverted = !swapFooter.quoteInverted
                }

                Item { Layout.fillWidth: true }

                StatusFlatButton {
                    id: slippageButton
                    objectName: "slippageButton"
                    icon.name: "filter"
                    size: StatusBaseButton.Size.Small
                    rightPadding: 0
                    text: "%1%".arg(LocaleUtils.numberToLocaleString(root.swapInputParamsForm.selectedSlippage))
                    textColor: Theme.palette.directColor1
                    hoverColor: StatusColors.transparent
                    onClicked: swapSlippagePopupComponent.createObject(root).open()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.padding
                visible: swapFooter.hasProposal

                component MetricRow: Row {
                    spacing: Theme.halfPadding
                }

                MetricRow {
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        icon: "filter"
                        color: Theme.palette.directColor4
                    }
                    StatusBaseText {
                        objectName: "routeOrderButton"
                        anchors.verticalCenter: parent.verticalCenter
                        text: d.routeOrderName
                        font.weight: Font.Medium
                        color: Theme.palette.directColor1

                        StatusToolTip {
                            visible: routeOrderMouseArea.containsMouse
                            text: qsTr("Choose route")
                        }

                        StatusMouseArea {
                            id: routeOrderMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: swapRoutePopupComponent.createObject(root).open()
                        }
                    }
                    StatusFlatRoundButton {
                        objectName: "routeProviderInfoIcon"
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: width/2
                        type: StatusFlatRoundButton.Type.Tertiary
                        icon.name: "info"
                        icon.width: 16
                        icon.height: 16
                        icon.color: Theme.palette.directColor4
                        tooltip.text: !!root.swapAdaptor.swapOutputData.txProviderTool
                                      ? qsTr("by %1 via %2").arg(d.serviceProviderName)
                                                            .arg(root.swapAdaptor.swapOutputData.txProviderTool)
                                      : qsTr("by %1").arg(d.serviceProviderName)
                    }
                }

                Item { Layout.fillWidth: true }

                MetricRow {
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        icon: "gas"
                        color: Theme.palette.directColor4
                    }
                    StatusBaseText {
                        objectName: "strategyFees"
                        text: root.swapAdaptor.currencyStore.formatCurrencyAmount(
                                  root.swapAdaptor.swapOutputData.txFeesInFiat, root.swapAdaptor.currencyStore.currentCurrency)
                        color: Theme.palette.directColor4
                    }
                }

                MetricRow {
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        icon: "time"
                        color: Theme.palette.directColor4
                    }
                    StatusBaseText {
                        objectName: "strategyTime"
                        text: WalletUtils.getLabelForEstimatedTxTime(root.swapAdaptor.swapOutputData.estimatedTime, true)
                        color: Theme.palette.directColor4
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Theme.padding
                visible: !!root.swapInputParamsForm.fromGroupKey

                StatusSlider {
                    id: amountSlider
                    objectName: "amountSlider"
                    Layout.fillWidth: true
                    enabled: payPanel.maxCryptoBalance > 0
                    from: 0
                    to: payPanel.maxSafeCryptoValue
                    stepSize: payPanel.maxSafeCryptoValue > 0
                              ? Math.pow(10, Math.floor(Math.log10(payPanel.maxSafeCryptoValue)) - 2)
                              : 1
                    snapMode: Slider.SnapAlways
                    onMoved: payPanel.setAmount(value)

                    Binding {
                        target: amountSlider
                        property: "value"
                        value: payPanel.value
                        when: !amountSlider.pressed
                        restoreMode: Binding.RestoreBindingOrValue
                    }
                }

                StatusBaseText {
                    objectName: "amountPercent"
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: "%1%".arg(LocaleUtils.numberToLocaleString(
                                        payPanel.maxSafeCryptoValue > 0
                                        ? Math.round(amountSlider.value / payPanel.maxSafeCryptoValue * 100) : 0, 0))
                    font.weight: Font.Medium
                    color: Theme.palette.directColor1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Theme.halfPadding
                visible: !!root.swapInputParamsForm.fromTokenAmount

                StatusButton {
                    id: signButton
                    objectName: "signButton"
                    Layout.fillWidth: true
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
                        if (swapFooter.loading)
                            return qsTr("Fetching quote...")
                        return qsTr("Confirm swap + bridge")
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

                StatusButton {
                    objectName: "refreshQuoteButton"
                    Layout.preferredWidth: signButton.height
                    Layout.preferredHeight: signButton.height
                    icon.name: "refresh"
                    type: StatusBaseButton.Type.Normal
                    enabled: swapFooter.hasProposal && !swapFooter.loading
                    onClicked: swapFooter.refresh()
                }
            }
        }
    }

    Component {
        id: swapRoutePopupComponent
        SwapRoutePopup {
            destroyOnClose: true
            routeOrder: root.swapInputParamsForm.selectedRouteOrder
            onRouteOrderSelected: order => root.swapInputParamsForm.selectedRouteOrder = order
        }
    }

    Component {
        id: swapSlippagePopupComponent
        SwapSlippagePopup {
            destroyOnClose: true
            slippageValue: root.swapInputParamsForm.selectedSlippage
            onSlippageSelected: value => root.swapInputParamsForm.selectedSlippage = value
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
            txProviderTool: root.swapAdaptor.swapOutputData.txProviderTool
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
            txProviderTool: root.swapAdaptor.swapOutputData.txProviderTool

            onAccepted: {
                root.swapAdaptor.sendSwapTx()
                root.close()
            }
        }
    }
}
