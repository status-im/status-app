import QtQuick
import QtQuick.Controls

import QtModelsToolkit

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.popups.simpleSend
import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet

import shared.popups.send
import shared.stores as SharedStores
import shared.stores.send

import utils

// TODO: Update the API to be explicit and avoid direct store access
SimpleSendModal {
    id: simpleSendModal

    required property SendModalHandler sendHandler

    recipientIsNewAccount: !!handler.recipientIsNewAccountAggregator.value
    accountsModel: handler.accountsSelectorAdaptor.processedWalletAccounts
    assetsModel: handler.assetsSelectorModel
    groupedAccountAssetsModel: sendHandler.groupedAccountAssetsModel
    flatCollectiblesModel: handler.collectiblesSelectorModel
                           ? handler.collectiblesSelectorModel.filteredFlatModel
                           : null
    collectiblesModel: handler.collectiblesSelectorModel
    networksModel: sendHandler.filteredFlatNetworksModel
    recipientsModel: handler.recipientViewAdaptor.recipientsModel
    recipientsFilterModel: handler.recipientViewAdaptor.recipientsFilterModel

    highestTabElementCount: handler.recipientViewAdaptor.highestTabElementCount
    currentCurrency: sendHandler.currentCurrency
    fnFormatCurrencyAmount: sendHandler.fnFormatCurrencyAmount
    fnResolveENS: sendHandler.fnResolveENS
    marketDataNotAvailable: handler.marketDataNotAvailable

    getTokenByKeyOrGroupKeyFromAllTokens: WalletStores.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens
    buyEnabled: sendHandler.buyEnabled

    onOpened: {
        if(isValidParameter(sendHandler.simpleSendParams.interactive)) {
            interactive = sendHandler.simpleSendParams.interactive
        }
        if(isValidParameter(sendHandler.simpleSendParams.displayOnlyAssets)) {
            displayOnlyAssets = sendHandler.simpleSendParams.displayOnlyAssets
        }
        if(isValidParameter(sendHandler.simpleSendParams.sendType)) {
            sendType = sendHandler.simpleSendParams.sendType
        }
        if(isValidParameter(sendHandler.simpleSendParams.selectedAccountAddress) &&
                !!sendHandler.simpleSendParams.selectedAccountAddress) {
            selectedAccountAddress = sendHandler.simpleSendParams.selectedAccountAddress
        }
        if(isValidParameter(sendHandler.simpleSendParams.selectedGroupKey)) {
            selectedGroupKey = sendHandler.simpleSendParams.selectedGroupKey
        }
        if(isValidParameter(sendHandler.simpleSendParams.selectedChainId)) {
            selectedChainId = sendHandler.simpleSendParams.selectedChainId
        }
        if(isValidParameter(sendHandler.simpleSendParams.selectedRawAmount)) {
            selectedRawAmount = sendHandler.simpleSendParams.selectedRawAmount
        }
        if(isValidParameter(sendHandler.simpleSendParams.selectedRecipientAddress)) {
            selectedAddress = sendHandler.simpleSendParams.selectedRecipientAddress
        }
        if(isValidParameter(sendHandler.simpleSendParams.publicKey)) {
            publicKey = sendHandler.simpleSendParams.publicKey
        }
        if(isValidParameter(sendHandler.simpleSendParams.ensName)) {
            ensName = sendHandler.simpleSendParams.ensName
        }
        if(isValidParameter(sendHandler.simpleSendParams.stickersPackId)) {
            stickersPackId = sendHandler.simpleSendParams.stickersPackId
        }
        if(isValidParameter(sendHandler.simpleSendParams.transferOwnership)) {
            transferOwnership = sendHandler.simpleSendParams.transferOwnership
        }
    }

    function isValidParameter(param) {
        return param !== undefined && param !== null
    }

    onClosed: {
        destroy()
        sendHandler.transactionStoreNew.resetData()
    }

    onFormChanged: {
        handler.resetRouterValues()
        if(allValuesFilledCorrectly) {
            handler.uuid = Utils.uuid()
            simpleSendModal.routesLoading = true
            sendHandler.transactionStoreNew.fetchSuggestedRoutes(handler.uuid,
                                                          sendType,
                                                          selectedChainId,
                                                          selectedAccountAddress,
                                                          selectedRecipientAddress,
                                                          selectedRawAmount,
                                                          selectedGroupKey,
                                                          /*amountOut = */ "0",
                                                          /*toToken =*/ "",
                                                          /*slippagePercentage*/ "",
                                                          handler.extraParamsJson)
        }
    }

    onReviewSendClicked: {
        if(sendType === Constants.SendType.ERC1155Transfer ||
                sendType === Constants.SendType.ERC721Transfer) {
            const selectedCollectible =
                                      SQUtils.ModelUtils.getByKey(sendHandler.collectiblesBySymbolModel, "key", selectedGroupKey)
            let contractAddress = !!selectedCollectible ? selectedCollectible.contractAddress : ""
            let tokenId = !!selectedCollectible ? selectedCollectible.tokenId : ""
            if (!contractAddress) {
                const parts = selectedGroupKey.split("-")
                if (parts.length >= 3) {
                    contractAddress = parts[1]
                    tokenId = parts[2]
                }
            }
            if(!!contractAddress && !!tokenId) {
                sendHandler.fnGetDetailedCollectible(simpleSendModal.selectedChainId ,
                                              contractAddress,
                                              tokenId)
            }
        }

        handler.reviewNext()

        Global.openPopup(sendSignModalCmp)
    }

    onLaunchBuyFlow: {
        sendHandler.launchBuyFlowRequested(selectedAccountAddress, selectedChainId, selectedGroupKey)
    }

    onSearchInAssets: (keyword) => handler.assetsSelectorModel.search(keyword)

    onFetchMoreAssets: {
        handler.assetsSelectorModel.fetchMore()
    }

    ModelEntry {
        id: txPathUnderReviewEntry
        sourceModel: handler.fetchedPathModel
        key: "index"
        value: handler.indexOfTxPathUnderReview
    }

    QtObject {
        id: handler
        property string uuid
        property var fetchedPathModel

        signal refreshTxSettings()

        readonly property bool marketDataNotAvailable: {
            if (sendHandler.networkConnectionStore.networkConnectionModuleInst.marketValuesNetworkConnection.completelyDown)
                return true
            const nativeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
            const nativeToken = SQUtils.ModelUtils.getByKey(sendHandler.tokenGroupsModel, "key", nativeTokenGroupKey)
            const price = nativeToken?.marketDetails?.currencyPrice
            return !!price && (price.amount == null || price.amount === 0)
        }

        readonly property string extraParamsJson: {
            if (!!simpleSendModal.stickersPackId) {
                return JSON.stringify({[Constants.suggestedRoutesExtraParamsProperties.packId]: simpleSendModal.stickersPackId})
            }
            if (!!simpleSendModal.ensName && !!simpleSendModal.publicKey) {
                return JSON.stringify({[Constants.suggestedRoutesExtraParamsProperties.username]: simpleSendModal.ensName,
                                          [Constants.suggestedRoutesExtraParamsProperties.publicKey]: simpleSendModal.publicKey})
            }
            return ""
        }

        property int indexOfTxPathUnderReview: -1
        readonly property bool reviewingLastTxPath: !!handler.fetchedPathModel && handler.indexOfTxPathUnderReview === handler.fetchedPathModel.ModelCount.count - 1

        property bool approvalForTxPathUnderReviewReviewed: false
        readonly property bool reviewApprovalForTxPathUnderReview: !!txPathUnderReviewEntry.item
                                                                   && txPathUnderReviewEntry.item.approvalRequired
                                                                   && !handler.approvalForTxPathUnderReviewReviewed

        function reviewNext() {
            if (!handler.reviewApprovalForTxPathUnderReview) {
                handler.indexOfTxPathUnderReview++
                handler.approvalForTxPathUnderReviewReviewed = false
            } else {
                handler.approvalForTxPathUnderReviewReviewed = true
            }
        }

        function handleReject() {
            if (handler.approvalForTxPathUnderReviewReviewed) {
                handler.approvalForTxPathUnderReviewReviewed = false
            } else {
                handler.indexOfTxPathUnderReview--
            }
        }

        function routesFetched(returnedUuid, pathModel, errCode, errDescription) {
            simpleSendModal.routesLoading = false
            if(returnedUuid !== handler.uuid) {
                // Suggested routes for a different fetch, ignore
                return
            }
            simpleSendModal.routerErrorCode = errCode
            simpleSendModal.routerError = WalletUtils.getRouterErrorBasedOnCode(errCode)
            simpleSendModal.routerErrorDetails = "%1 - %2".arg(errCode).arg(
                        WalletUtils.getRouterErrorDetailsOnCode(errCode, errDescription))
            fetchedPathModel = pathModel
            handler.refreshTxSettings()
        }

        function transactionSent(returnedUuid, chainId, approvalTx, txHash, error) {
            if(returnedUuid !== handler.uuid) {
                // Suggested routes for a different fetch, ignore
                return
            }
            if (!!error) {
                handleReject()
                if (error.includes(Constants.walletSection.authenticationCanceled)) {
                    return
                }
                if (error === Constants.walletSection.routeNeedsReview) {
                    // nothing was sent; fetch a new route to review
                    simpleSendModal.formChanged()
                    return
                }
                simpleSendModal.routerError = error
                return
            }
            simpleSendModal.close()
        }

        function userSuccessfullyAuthenticated(uuid) {
            if(uuid !== handler.uuid) {
                return
            }
            // TODO: commented this out as closing this popup rests the variables on nim side and tx fails
            // simpleSendModal.close()
        }

        readonly property var recipientViewAdaptor: RecipientViewAdaptor {
            savedAddressesModel: sendHandler.savedAddressesModel
            accountsModel: sendHandler.walletAccountsModel
            recentRecipientsModel: sendHandler.recentRecipientsModel

            selectedSenderAddress: simpleSendModal.selectedAccountAddress
            selectedRecipientType: simpleSendModal.selectedRecipientType
            searchPattern: simpleSendModal.recipientSearchPattern
        }

        readonly property var accountsSelectorAdaptor: WalletAccountsSelectorAdaptor {
            accounts: sendHandler.walletAccountsModel
            assetsModel: sendHandler.groupedAccountAssetsModel
            tokenGroupsModel: sendHandler.tokenGroupsModel
            filteredFlatNetworksModel: sendHandler.filteredFlatNetworksModel

            selectedGroupKey: simpleSendModal.selectedGroupKey
            selectedNetworkChainId: simpleSendModal.selectedChainId

            fnFormatCurrencyAmountFromBigInt: sendHandler.fnFormatCurrencyAmountFromBigInt
        }

        // Terminal picker model (send/owned) as { model, id }. The producer
        // keeps it fed with the owned source; the per-modal params are driven
        // below. This handler lives inside SimpleSendModal (destroyed on close),
        // so the model is released on destruction to stop the producer tracking
        // it (avoids a per-open leak, like the swap/buy modals).
        readonly property var assetsSelector: WalletStores.RootStore.tokensStore.createTokenSelectorModel(0)
        readonly property var assetsSelectorModel: handler.assetsSelector.model

        // Terminal collectibles picker model as { model, id }. Replaces the
        // O(collectibles) CollectiblesSelectionAdaptor proxy chain; the Nim
        // model derives both the grouped and the flat views in ~2ms, so it is
        // built eagerly with the assets selector (no modal-open deferral).
        // Released on destruction to stop the producer tracking it.
        readonly property var collectiblesSelector: sendHandler.walletCollectiblesStore.createCollectiblesSelectorModel()
        readonly property var collectiblesSelectorModel: handler.collectiblesSelector.model

        Component.onDestruction: {
            WalletStores.RootStore.tokensStore.releaseTokenSelectorModel(handler.assetsSelector.id)
            sendHandler.walletCollectiblesStore.releaseCollectiblesSelectorModel(handler.collectiblesSelector.id)
        }

        readonly property Binding _sendAccountBinding: Binding {
            target: handler.assetsSelectorModel
            property: "accountAddress"
            value: simpleSendModal.selectedAccountAddress
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _sendChainBinding: Binding {
            target: handler.assetsSelectorModel
            property: "enabledChainId"
            value: simpleSendModal.selectedChainId
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _sendShowCommunityBinding: Binding {
            target: handler.assetsSelectorModel
            property: "showCommunityAssets"
            value: sendHandler.showCommunityAssetsInSend
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _sendShowZeroBinding: Binding {
            target: handler.assetsSelectorModel
            property: "showZeroBalanceForDefaultTokens"
            value: true
            restoreMode: Binding.RestoreNone
        }
        readonly property Connections _sendSectionSync: Connections {
            target: simpleSendModal
            function onSelectedChainIdChanged() { handler.updateSendSectionNames() }
        }
        function updateSendSectionNames() {
            if (!handler.assetsSelectorModel)
                return
            const chainName = SQUtils.ModelUtils.getByKey(
                sendHandler.flatNetworksModel, "chainId", simpleSendModal.selectedChainId, "chainName") || ""
            handler.assetsSelectorModel.setSectionNames(
                qsTr("Your assets on %1").arg(chainName), qsTr("Popular assets"))
        }
        Component.onCompleted: handler.updateSendSectionNames()

        // Per-modal params for the collectibles picker model. Mirror the
        // retired adaptor's inputs (soulbound collectibles are dropped in the
        // Nim producer; networks are joined there too).
        readonly property Binding _collectiblesAccountBinding: Binding {
            target: handler.collectiblesSelectorModel
            property: "accountKey"
            value: simpleSendModal.selectedAccountAddress
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _collectiblesChainBinding: Binding {
            target: handler.collectiblesSelectorModel
            property: "enabledChainId"
            value: simpleSendModal.selectedChainId
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _collectiblesFilterBinding: Binding {
            target: handler.collectiblesSelectorModel
            property: "filterCommunityOwnerAndMasterTokens"
            value: !simpleSendModal.transferOwnership
            restoreMode: Binding.RestoreNone
        }
        readonly property Binding _collectiblesPinnedBinding: Binding {
            target: handler.collectiblesSelectorModel
            property: "pinnedTokenJson"
            value: simpleSendModal.transferOwnership && !!simpleSendModal.selectedGroupKey
                   ? JSON.stringify({ key: simpleSendModal.selectedGroupKey,
                                      name: sendHandler.simpleSendParams.tokenName ?? "",
                                      icon: sendHandler.simpleSendParams.tokenIcon ?? "" })
                   : ""
            restoreMode: Binding.RestoreNone
        }

        readonly property FunctionAggregator totalFeesAggregator: FunctionAggregator {
            model: handler.fetchedPathModel
            initialValue: "-1"
            roleName: "txTotalFee"

            aggregateFunction: (aggr, value) => {
                                    if (aggr === "-1") {
                                        return value
                                    }
                                    return SQUtils.AmountsArithmetic.sum(
                                        SQUtils.AmountsArithmetic.fromString(aggr),
                                        SQUtils.AmountsArithmetic.fromString(value)).toString()
                                }

            onValueChanged: {
                const nativeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
                const nativeToken = SQUtils.ModelUtils.getByKey(sendHandler.tokenGroupsModel, "key", nativeTokenGroupKey)
                let nativeTokenFiatValue = !!nativeToken ? nativeToken.marketDetails.currencyPrice.amount: 1
                let totalFees = Utils.nativeTokenRawToDecimal(simpleSendModal.selectedChainId, value)

                simpleSendModal.estimatedCryptoFees = sendHandler.fnFormatCurrencyAmount(totalFees.toString(), nativeToken.symbol)

                // Use GWEI fees as fiat fees when market data is not available
                if (handler.marketDataNotAvailable) {
                    const totalFeesInGwei = SQUtils.AmountsArithmetic.round( Utils.nativeTokenRawToGas(simpleSendModal.selectedChainId, value), 0)
                    const feeSymbol = Utils.getNativeGasTokenSymbol(simpleSendModal.selectedChainId)
                    simpleSendModal.estimatedFiatFees = totalFeesInGwei.toString() + " " + feeSymbol
                } else {
                    let totalFeesInFiat = sendHandler.fnFormatCurrencyAmount(nativeTokenFiatValue*totalFees, sendHandler.currentCurrency).toString()
                    simpleSendModal.estimatedFiatFees = totalFeesInFiat
                }
            }
        }

        // e.g. EIP-8037 state gas
        readonly property FunctionAggregator recipientIsNewAccountAggregator: FunctionAggregator {
            model: handler.fetchedPathModel
            initialValue: false
            roleName: "recipientIsNewAccount"

            aggregateFunction: (aggr, value) => aggr || !!value
        }

        readonly property FunctionAggregator estimatedTimeAggregator: FunctionAggregator {
            model: handler.fetchedPathModel
            initialValue: -1
            roleName: "estimatedTime"

            aggregateFunction: (aggr, value) => aggr < value? value : aggr

            onValueChanged: {
                simpleSendModal.estimatedTime = WalletUtils.formatEstimatedTime(value)
            }
        }

        readonly property Connections rootConnections: Connections {
            target: simpleSendModal.sendHandler
            function onEnsNameResolved(resolvedPubKey, resolvedAddress, uuid) {
                simpleSendModal.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
            }
        }

        readonly property Connections storeConnections: Connections {
            target: sendHandler.transactionStoreNew

            function onSuggestedRoutesReady(uuid, pathModel, errCode, errDescription) {
                handler.routesFetched(uuid, pathModel, errCode, errDescription)
            }

            function onTransactionSent(uuid, chainId, approvalTx, txHash, error) {
                handler.transactionSent(uuid, chainId, approvalTx, txHash, error)
            }

            function onSuccessfullyAuthenticated(uuid) {
                handler.userSuccessfullyAuthenticated(uuid)
            }
        }

        function resetRouterValues() {
            sendHandler.transactionStoreNew.resetData()
            handler.uuid = ""
            handler.fetchedPathModel = null
            handler.indexOfTxPathUnderReview = -1
            simpleSendModal.estimatedCryptoFees = ""
            simpleSendModal.estimatedFiatFees = ""
            simpleSendModal.estimatedTime = ""
            simpleSendModal.routerErrorCode = ""
            simpleSendModal.routerError = ""
            simpleSendModal.routerErrorDetails = ""
        }
    }

    SignSendAdaptor {
        id: signSendAdaptor

        palette: sendHandler.popupParent.Theme.palette
        accountKey: simpleSendModal.selectedAccountAddress
        accountsModel: sendHandler.walletAccountsModel
        recipientModel: handler.recipientViewAdaptor.recipientsModel
        chainId: simpleSendModal.selectedChainId
        networksModel: sendHandler.flatNetworksModel
        groupKey: simpleSendModal.selectedGroupKey
        tokenGroupsModel: sendHandler.tokenGroupsModel
        selectedAmountInBaseUnit: simpleSendModal.selectedRawAmount
        selectedRecipientAddress: simpleSendModal.selectedRecipientAddress
    }

    Component {
        id: sendSignModalCmp

        // TODO: Update the API to be explicit and avoid direct store access
        SendSignModal {
            closePolicy: Popup.CloseOnEscape
            destroyOnClose: true
            // Unused
            formatBigNumber: function(number, symbol, noSymbolOption) {}

            tokenSymbol: !!signSendAdaptor.selectedAsset &&
                             !!signSendAdaptor.selectedAsset.symbol ?
                                 signSendAdaptor.selectedAsset.symbol: ""
            tokenAmount: signSendAdaptor.selectedAmount
            tokenContractAddress: signSendAdaptor.selectedAssetContractAddress
            tokenIcon: !!signSendAdaptor.selectedAsset &&
                       !!signSendAdaptor.selectedAsset.logoUri ?
                           signSendAdaptor.selectedAsset.logoUri: ""

            accountName: signSendAdaptor.selectedAccount.name
            accountAddress: signSendAdaptor.selectedAccount.address
            accountEmoji: signSendAdaptor.selectedAccount.emoji
            accountColor: Utils.getColorForId(Theme.palette, signSendAdaptor.selectedAccount.colorId)

            recipientAddress: signSendAdaptor.recipientAddress
            recipientName: signSendAdaptor.recipientName
            recipientEns: signSendAdaptor.recipientEns
            recipientEmoji: signSendAdaptor.recipientEmoji
            recipientWalletColor: signSendAdaptor.recipientWalletColor

            networkShortName: signSendAdaptor.selectedNetwork.shortName
            networkName: signSendAdaptor.selectedNetwork.chainName
            networkIconPath: Assets.svg(signSendAdaptor.selectedNetwork.iconUrl)
            networkBlockExplorerUrl: signSendAdaptor.selectedNetwork.blockExplorerURL
            networkChainId: signSendAdaptor.selectedNetwork.chainId

            selectedFeeMode: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalGasFeeMode
                    }
                    return txPathUnderReviewEntry.item.txGasFeeMode
                }
                return Constants.FeePriorityModeType.Normal
            }

            fromChainEIP1559Compliant: !!txPathUnderReviewEntry.item && txPathUnderReviewEntry.item.fromChainEIP1559Compliant
            fromChainNoBaseFee: !!txPathUnderReviewEntry.item && txPathUnderReviewEntry.item.fromChainNoBaseFee
            fromChainNoPriorityFee: !!txPathUnderReviewEntry.item && txPathUnderReviewEntry.item.fromChainNoPriorityFee

            currentGasPrice: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedNonEIP1559GasPrice : ""
            currentBaseFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.currentBaseFee : ""
            currentSuggestedMinPriorityFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedMinPriorityFee : ""
            currentSuggestedMaxPriorityFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedMaxPriorityFee : ""
            currentGasAmount: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.suggestedApprovalGasAmount
                    }
                    return txPathUnderReviewEntry.item.suggestedTxGasAmount
                }
                return ""
            }
            // raw node estimate; "0" (a stand-in) means no minimum
            minGasAmount: {
                if (!txPathUnderReviewEntry.item)
                    return ""
                const estimated = handler.reviewApprovalForTxPathUnderReview
                        ? txPathUnderReviewEntry.item.estimatedApprovalGasAmount
                        : txPathUnderReviewEntry.item.estimatedTxGasAmount
                return !!estimated && estimated !== "0" ? estimated : ""
            }
            currentNonce: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.suggestedApprovalTxNonce
                    }
                    return txPathUnderReviewEntry.item.suggestedTxNonce
                }
                return 0
            }

            fnGetPriceInCurrencyForFee: function(rawFee) {
                if (!rawFee) {
                    return ""
                }

                // Use GWEI when market data is not available
                if (handler.marketDataNotAvailable) {
                    const roundedGwei = SQUtils.AmountsArithmetic.round( Utils.nativeTokenRawToGas(simpleSendModal.selectedChainId, rawFee), 0)
                    const feeSymbol = Utils.getNativeGasTokenSymbol(simpleSendModal.selectedChainId)
                    return roundedGwei.toString() + " " + feeSymbol
                }

                const feeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
                const feeToken = SQUtils.ModelUtils.getByKey(sendHandler.tokenGroupsModel, "key", feeTokenGroupKey)
                const decimalFee = Utils.nativeTokenRawToDecimal(simpleSendModal.selectedChainId, rawFee)
                const feeTokenPrice = !!feeToken ? feeToken.marketDetails.currencyPrice.amount: 1
                return sendHandler.fnFormatCurrencyAmount(feeTokenPrice*decimalFee, sendHandler.currentCurrency).toString()
            }

            fnGetPriceInNativeTokenForFee: function(rawFee) {
                if (!rawFee) {
                    return ""
                }
                const feeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
                return sendHandler.fnFormatCurrencyAmount(rawFee, feeTokenGroupKey).toString()
            }

            fnGetEstimatedTime: function(gasPrice, rawBaseFee, rawPriorityFee) {
                if (!txPathUnderReviewEntry.item) {
                    return ""
                }
                const chainId = txPathUnderReviewEntry.item.fromChain
                return sendHandler.transactionStoreNew.getEstimatedTime(chainId, gasPrice, rawBaseFee, rawPriorityFee)
            }

            normalPrice: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        const fee = !txPathUnderReviewEntry.item.fromChainEIP1559Compliant?
                                      SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.approvalGasPrice)
                                    : SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasLowLevel)
                        return SQUtils.AmountsArithmetic.times(
                                         fee,
                                         SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedApprovalGasAmount)).toString()
                    }
                    const fee = !txPathUnderReviewEntry.item.fromChainEIP1559Compliant?
                                  SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.txGasPrice)
                                : SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasLowLevel)
                    return SQUtils.AmountsArithmetic.times(
                                     fee,
                                     SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedTxGasAmount)).toString()
                }
                return ""
            }
            normalGasPrice: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.approvalGasPrice).toString()
                    }
                    return SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.txGasPrice).toString()
                }
                return ""
            }
            normalBaseFee: !!txPathUnderReviewEntry.item?
                               SQUtils.AmountsArithmetic.sub(SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasLowLevel),
                                                             SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedPriorityFeePerGasLowLevel)).toString()
                             : ""
            normalPriorityFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedPriorityFeePerGasLowLevel : ""
            normalTime: {
                if (!!txPathUnderReviewEntry.item) {
                    if (!txPathUnderReviewEntry.item.fromChainEIP1559Compliant) {
                        return txPathUnderReviewEntry.item.suggestedNonEIP1559EstimatedTime
                    }
                    return txPathUnderReviewEntry.item.suggestedEstimatedTimeLowLevel
                }
                return 0
            }

            fastPrice: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return SQUtils.AmountsArithmetic.times(
                                           SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasMediumLevel),
                                           SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedApprovalGasAmount)).toString()
                    }
                    return SQUtils.AmountsArithmetic.times(
                                       SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasMediumLevel),
                                       SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedTxGasAmount)).toString()
                }
                return ""
            }
            fastBaseFee: !!txPathUnderReviewEntry.item?
                               SQUtils.AmountsArithmetic.sub(SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasMediumLevel),
                                                             SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedPriorityFeePerGasMediumLevel)).toString()
                             : ""
            fastPriorityFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedPriorityFeePerGasMediumLevel : ""
            fastTime: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedEstimatedTimeMediumLevel : 0

            urgentPrice: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return SQUtils.AmountsArithmetic.times(
                                           SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasHighLevel),
                                           SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedApprovalGasAmount)).toString()
                    }
                    return SQUtils.AmountsArithmetic.times(
                                       SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasHighLevel),
                                       SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedTxGasAmount)).toString()
                }
                return ""
            }
            urgentBaseFee: !!txPathUnderReviewEntry.item?
                               SQUtils.AmountsArithmetic.sub(SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedMaxFeesPerGasHighLevel),
                                                             SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.suggestedPriorityFeePerGasHighLevel)).toString()
                             : ""
            urgentPriorityFee: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedPriorityFeePerGasHighLevel : ""
            urgentTime: !!txPathUnderReviewEntry.item? txPathUnderReviewEntry.item.suggestedEstimatedTimeHighLevel : 0

            customGasPrice: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalGasPrice
                    }
                    return txPathUnderReviewEntry.item.txGasPrice
                }
                return ""
            }
            customBaseFee: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalBaseFee
                    }
                    return txPathUnderReviewEntry.item.txBaseFee
                }
                return ""
            }
            customPriorityFee: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalPriorityFee
                    }
                    return txPathUnderReviewEntry.item.txPriorityFee
                }
                return ""
            }
            customGasAmount: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalGasAmount
                    }
                    return txPathUnderReviewEntry.item.txGasAmount
                }
                return ""
            }
            customNonce: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return txPathUnderReviewEntry.item.approvalTxNonce
                    }
                    return txPathUnderReviewEntry.item.txNonce
                }
                return ""
            }

            readonly property var decimalTotalFees: {
                let rawTotalFee = "0"
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        rawTotalFee = SQUtils.AmountsArithmetic.sum(SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.approvalFee),
                                                                     SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.approvalL1Fee)).toString()
                    } else {
                        rawTotalFee = SQUtils.AmountsArithmetic.sum(SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.txFee),
                                                                     SQUtils.AmountsArithmetic.fromString(txPathUnderReviewEntry.item.txL1Fee)).toString()
                    }
                }
                return Utils.nativeTokenRawToDecimal(simpleSendModal.selectedChainId, rawTotalFee)
            }

            fiatFees: {
                if (handler.marketDataNotAvailable) {
                    const totalFeesInGwei = SQUtils.AmountsArithmetic.round( Utils.nativeTokenDecimalToGas(simpleSendModal.selectedChainId, decimalTotalFees), 0)
                    const feeSymbol = Utils.getNativeGasTokenSymbol(simpleSendModal.selectedChainId)
                    return totalFeesInGwei.toString() + " " + feeSymbol
                } else {
                    const feeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
                    const feeToken = SQUtils.ModelUtils.getByKey(sendHandler.tokenGroupsModel, "key", feeTokenGroupKey)
                    const feeTokenPrice = !!feeToken ? feeToken.marketDetails.currencyPrice.amount: 1
                    return sendHandler.fnFormatCurrencyAmount(feeTokenPrice*decimalTotalFees, sendHandler.currentCurrency).toString()
                }
            }

            cryptoFees: {
                const feeTokenGroupKey = Utils.getNativeTokenGroupKey(simpleSendModal.selectedChainId)
                const feeToken = SQUtils.ModelUtils.getByKey(sendHandler.tokenGroupsModel, "key", feeTokenGroupKey)
                return sendHandler.fnFormatCurrencyAmount(decimalTotalFees.toString(), feeToken.symbol)
            }

            estimatedTime: {
                if (!!txPathUnderReviewEntry.item) {
                    if (handler.reviewApprovalForTxPathUnderReview) {
                        return WalletUtils.formatEstimatedTime(txPathUnderReviewEntry.item.approvalEstimatedTime)
                    }
                    return WalletUtils.formatEstimatedTime(txPathUnderReviewEntry.item.txEstimatedTime)
                }
                return WalletUtils.formatEstimatedTime(0)
            }

            keyUid: signSendAdaptor.selectedAccount.keyUid
            migratedToColdWallet: signSendAdaptor.selectedAccount.migratedToColdWallet

            isCollectible: simpleSendModal.sendType === Constants.SendType.ERC1155Transfer ||
                           simpleSendModal.sendType === Constants.SendType.ERC721Transfer
            isCollectibleLoading: sendHandler.isDetailedCollectibleLoading
            collectibleContractAddress: sendHandler.detailedCollectible.contractAddress
            collectibleTokenId: sendHandler.detailedCollectible.tokenId
            collectibleName: sendHandler.detailedCollectible.name
            collectibleBackgroundColor: sendHandler.detailedCollectible.backgroundColor
            collectibleMediaUrl: sendHandler.detailedCollectible.mediaUrl
            collectibleMediaType: sendHandler.detailedCollectible.mediaType
            collectibleFallbackImageUrl: sendHandler.detailedCollectible.imageUrl

            fnGetOpenSeaExplorerUrl: sendHandler.fnGetOpenSeaUrl

            Component.onCompleted: {
                handler.refreshTxSettings.connect(refreshTxSettings)
            }

            closeHandler: function() {
                handler.handleReject()
                close()
            }

            onUpdateTxSettings: (selectedFeeMode, customNonce, customGasAmount, gasPrice, maxFeesPerGas, priorityFee) => {
                let pathName = ""
                let chainId = 0
                if (!!txPathUnderReviewEntry.item) {
                    pathName = txPathUnderReviewEntry.item.processorName
                    chainId = txPathUnderReviewEntry.item.fromChain
                }

                if (selectedFeeMode === Constants.FeePriorityModeType.Custom) {
                    sendHandler.transactionStoreNew.setCustomTxDetails(customNonce,
                                                                customGasAmount,
                                                                gasPrice,
                                                                maxFeesPerGas,
                                                                priorityFee,
                                                                handler.uuid,
                                                                pathName,
                                                                chainId,
                                                                handler.reviewApprovalForTxPathUnderReview,
                                                                "")
                    return
                }

                sendHandler.transactionStoreNew.setFeeMode(selectedFeeMode,
                                                    handler.uuid,
                                                    pathName,
                                                    chainId,
                                                    handler.reviewApprovalForTxPathUnderReview,
                                                    "")
            }

            onRejected: {
                handler.handleReject()
            }

            onAccepted: {
                if (handler.reviewingLastTxPath) {
                    sendHandler.transactionStoreNew.authenticateAndTransfer(handler.uuid, simpleSendModal.selectedAccountAddress)
                    return
                }
                handler.reviewNext()
            }
        }
    }
}
