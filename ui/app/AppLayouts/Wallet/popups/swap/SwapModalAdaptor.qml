import QtQml

import StatusQ
import StatusQ.Core.Utils

import utils

import shared.stores
import AppLayouts.Wallet
import AppLayouts.Wallet.stores as WalletStore

import QtModelsToolkit

QObject {
    id: root

    required property CurrenciesStore currencyStore
    required property WalletStore.WalletAssetsStore walletAssetsStore
    required property WalletStore.SwapStore swapStore
    required property SwapInputParamsForm swapFormData
    required property SwapOutputData swapOutputData
    required property NetworksStore networksStore

    // the below 2 properties holds the state of finding a swap proposal
    property bool validSwapProposalReceived: false
    property bool swapProposalLoading: false

    // the below 2 properties holds the state of finding a swap proposal
    property bool approvalPending: false
    property bool approvalSuccessful: false

    // the below property holds internal checks done by the SwapModal
    property bool amountEnteredGreaterThanBalance: false

    // To expose the selected from and to Token from the SwapModal
    readonly property var fromToken: fromTokenEntry.item
    readonly property var toToken: toTokenEntry.item

    readonly property string uuid: d.uuid
    readonly property var filteredFlatNetworksModel: root.networksStore.activeNetworks

    readonly property string errorMessage: d.errorMessage
    readonly property bool isEthBalanceInsufficient: d.isEthBalanceInsufficient
    readonly property bool isTokenBalanceInsufficient: d.isTokenBalanceInsufficient

    QtObject {
        id: d

        property string uuid
        // storing txHash to verify against tx completed event
        property string txHash

        readonly property string nativeTokenSymbol: Utils.getNativeTokenSymbol(root.swapFormData.selectedNetworkChainId)

        // Properties to handle error states
        readonly property bool isRouteEthBalanceInsufficient: root.validSwapProposalReceived && root.swapOutputData.errCode === Constants.routerErrorCodes.router.errNotEnoughNativeBalance

        readonly property bool isRouteTokenBalanceInsufficient: root.validSwapProposalReceived && root.swapOutputData.errCode === Constants.routerErrorCodes.router.errNotEnoughTokenBalance

        readonly property bool isTokenBalanceInsufficient: {
            if (!!root.fromToken && !!root.fromToken.symbol) {
                return (root.amountEnteredGreaterThanBalance || isRouteTokenBalanceInsufficient) &&
                        root.fromToken.symbol !== nativeTokenSymbol
            }
            return false
        }

        readonly property bool isEthBalanceInsufficient: {
            if (!!root.fromToken && !!root.fromToken.symbol) {
                return (root.amountEnteredGreaterThanBalance && root.fromToken.symbol === nativeTokenSymbol) ||
                        isRouteEthBalanceInsufficient
            }
            return false
        }

        readonly property bool isBalanceInsufficientForSwap: {
            if (!!root.fromToken && !!root.fromToken.symbol) {
                return (root.amountEnteredGreaterThanBalance && root.fromToken.symbol === nativeTokenSymbol) ||
                        (isTokenBalanceInsufficient && root.fromToken.symbol !== nativeTokenSymbol)
            }
            return false
        }

        readonly property bool isBalanceInsufficientForFees: !isBalanceInsufficientForSwap && isEthBalanceInsufficient

        property string errorMessage: {
            if (isBalanceInsufficientForSwap) {
                return qsTr("Insufficient funds for swap")
            } else if (isBalanceInsufficientForFees) {
                return qsTr("Not enough ETH to pay gas fees")
            } else if (root.swapOutputData.hasError) {
                // TOOD #15874: Unify with WalletUtils router error code handling
                switch (root.swapOutputData.errCode) {
                    case Constants.routerErrorCodes.processor.errPriceTimeout:
                        return qsTr("Fetching the price took longer than expected. Please, try again later.")
                    case Constants.routerErrorCodes.processor.errNotEnoughLiquidity:
                        return qsTr("Not enough liquidity. Lower token amount or try again later.")
                    case Constants.routerErrorCodes.processor.errPriceImpactTooHigh:
                        return qsTr("Price impact too high. Lower token amount or try again later.")
                    case Constants.routerErrorCodes.processor.errSwapParaswapCustomError:
                        const errMsg = qsTr("No routes found with enough liquidity")
                        if (root.swapOutputData.errDescription.indexOf(errMsg) !== -1) {
                            return qsTr("Not enough liquidity. Lower token amount or try again later.")
                        }
                }
                return qsTr("Something went wrong. Change amount, token or try again later.")
            }
            return ""
        }
    }

    ModelEntry {
        id: fromTokenEntry
        sourceModel: root.walletAssetsStore.walletTokensStore.tokenGroupsModel
        key: "key"
        value: root.swapFormData.fromGroupKey
    }

    ModelEntry {
        id: toTokenEntry
        sourceModel: root.walletAssetsStore.walletTokensStore.tokenGroupsModel
        key: "key"
        value: root.swapFormData.toGroupKey
    }

    Connections {
        target: root.swapStore
        function onSuggestedRoutesReady(txRoutes, errCode, errDescription) {
            if (txRoutes.uuid !== d.uuid) {
                // Suggested routes for a different fetch, ignore
                return
            }
            root.swapOutputData.reset()
            root.validSwapProposalReceived = false
            root.swapProposalLoading = false
            root.swapOutputData.rawPaths = txRoutes.rawPaths
            root.swapOutputData.errCode = errCode
            root.swapOutputData.errDescription = errDescription
            // if valid route was found
            if(txRoutes.suggestedRoutes.count > 0) {
                root.validSwapProposalReceived = true
                root.swapOutputData.toTokenAmount = AmountsArithmetic.div(AmountsArithmetic.fromString(txRoutes.amountToReceive), AmountsArithmetic.fromNumber(1, root.toToken.decimals)).toString()

                let gasTimeEstimate = txRoutes.gasTimeEstimate
                let totalTokenFeesInFiat = 0
                if (!!root.fromToken && !!root.fromToken.marketDetails && !!root.fromToken.marketDetails.currencyPrice)
                    totalTokenFeesInFiat = gasTimeEstimate.totalTokenFees * root.fromToken.marketDetails.currencyPrice.amount
                root.swapOutputData.totalFees = root.currencyStore.getFiatValue(gasTimeEstimate.totalFeesInNativeCrypto, d.nativeTokenSymbol) + totalTokenFeesInFiat
                let bestPath = ModelUtils.get(txRoutes.suggestedRoutes, 0, "route")

                root.swapOutputData.txFeesWei = AmountsArithmetic.sum(AmountsArithmetic.fromString(bestPath.txFeeInWei), AmountsArithmetic.fromString(bestPath.txL1FeeInWei)).toString()
                const txFeesNative = Utils.nativeTokenRawToDecimal(root.swapFormData.selectedNetworkChainId, root.swapOutputData.txFeesWei)
                root.swapOutputData.txFeesInFiat = root.currencyStore.getFiatValue(txFeesNative, d.nativeTokenSymbol)

                root.swapOutputData.approvalTxFeesWei = AmountsArithmetic.sum(AmountsArithmetic.fromString(bestPath.approvalFeeInWei), AmountsArithmetic.fromString(bestPath.approvalL1FeeInWei)).toString()
                const txApprovalFeesNative = Utils.nativeTokenRawToDecimal(root.swapFormData.selectedNetworkChainId, root.swapOutputData.approvalTxFeesWei)
                root.swapOutputData.approvalTxFeesFiat = root.currencyStore.getFiatValue(txApprovalFeesNative, d.nativeTokenSymbol)

                const totalMaxFeesInGasUnit = Math.ceil(bestPath.gasFees.maxFeePerGasM) * bestPath.gasAmount
                root.swapOutputData.maxFeesToReserveRaw = Utils.nativeTokenGasToRaw(root.swapFormData.selectedNetworkChainId, totalMaxFeesInGasUnit).toString()

                root.swapOutputData.approvalNeeded = !!bestPath ? bestPath.approvalRequired: false
                root.swapOutputData.approvalGasFees = !!bestPath ? bestPath.approvalGasFees.toString() : ""
                root.swapOutputData.approvalAmountRequired = !!bestPath ? bestPath.approvalAmountRequired: ""
                root.swapOutputData.approvalContractAddress = !!bestPath ? bestPath.approvalContractAddress: ""
                root.swapOutputData.estimatedTime = !!bestPath ? bestPath.estimatedTime: Constants.TransactionEstimatedTime.Unknown
                root.swapOutputData.txProviderName = !!bestPath ? bestPath.bridgeName: ""
                // TODO: should approval fees be included in maxFeesToReserveRaw?
            } else {
                root.swapOutputData.hasError = true
            }
            root.swapOutputData.hasError = root.swapOutputData.hasError || root.swapOutputData.errCode !== ""
        }

        function onTransactionSent(uuid, chainId, approvalTx, txHash, error) {
            if(root.swapOutputData.approvalNeeded && !root.approvalSuccessful) {
                if (uuid !== d.uuid || !!error) {
                    root.approvalPending = false
                    root.approvalSuccessful = false
                    return
                }
                root.approvalPending = true
                d.txHash = txHash
            }
        }

        function onTransactionSendingComplete(txHash, status) {
            if(d.txHash === txHash && root.swapOutputData.approvalNeeded && root.approvalPending) {
                root.approvalPending = false
                root.approvalSuccessful = status == "Success" // TODO: make a all tx statuses Constants (success, pending, failed)
                d.txHash = ""

                root.swapStore.reevaluateSwap(d.uuid, root.swapFormData.selectedNetworkChainId, true)
            }
        }
    }

    function reset() {
        d.uuid = ""
        root.swapFormData.resetFormData()
        root.swapOutputData.reset()
        root.validSwapProposalReceived = false
        root.swapProposalLoading = false
        root.approvalPending = false
        root.approvalSuccessful = false
        d.txHash = ""
    }

    function invalidateSuggestedRoute() {
        d.uuid = ""
        root.validSwapProposalReceived = false
        root.approvalPending = false
        root.approvalSuccessful = false
        root.swapOutputData.resetPathInfoAndError()
    }

    function fetchSuggestedRoutes(cryptoValueInRaw) {
        root.swapFormData.toTokenAmount = ""
        if (root.swapFormData.isFormFilledCorrectly() && !!cryptoValueInRaw) {
            // Identify new swap with a different uuid
            d.uuid = Utils.uuid()

            root.swapProposalLoading = true

            let accountAddress = root.swapFormData.selectedAccountAddress

            root.swapStore.fetchSuggestedRoutes(d.uuid, accountAddress, accountAddress,
                                                cryptoValueInRaw, "0", root.swapFormData.fromGroupKey, root.swapFormData.toGroupKey,
                                                root.swapFormData.selectedNetworkChainId, root.swapFormData.selectedNetworkChainId,
                                                Constants.SendType.Swap, root.swapFormData.selectedSlippage)
        } else {
            root.swapProposalLoading = false
            root.swapOutputData.reset()
        }
    }

    function sendApproveTx() {
        root.approvalPending = true
        root.swapStore.authenticateAndTransfer(d.uuid)
    }

    function sendSwapTx() {
        root.swapStore.authenticateAndTransfer(d.uuid)
    }

    function resetData() {
        root.swapStore.resetData()
    }
}
