pragma Singleton

import QtQuick

import utils
import StatusQ.Core.Theme

import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Wallet.stores as WalletStores
import shared.stores as SharedStores

QtObject {

    function calculateConfirmationTimestamp(chainLayer, timestamp) {
        if (chainLayer === 1) {
            return timestamp + 12 * 4 // A block on layer1 is every 12s
        }
        return timestamp
    }

    function calculateFinalisationTimestamp(chainLayer, timestamp) {
        if (chainLayer === 1) {
            return timestamp + 12 * 64 // A block on layer1 is every 12s
        }
        return timestamp + Constants.time.secondsIn7Days
    }

    function addressToDisplay(palette, address, shortForm, hovered) {
        let finalAddress = address
        if (shortForm) {
            finalAddress = StatusQUtils.Utils.elideText(address,6,4)
        }
        return hovered ? Utils.richColorText(finalAddress, palette.directColor1) : finalAddress
    }

    function preferredAddress(account) {
        if (!account)
            return ""
        return account.mixedcaseAddress || account.address || ""
    }

    /**
      Calculate max safe amount to be used when making a transaction

      This logic is here to make sure there is enough eth to pay for the gas.
      Context, when making a transaction, whatever the type: swap/bridge/send, you need eth to pay for the gas.

      rationale: https://github.com/status-im/status-app/pull/14959#discussion_r1627110880
      */
    function calculateMaxSafeSendAmount(value, symbol, chainId, cryptoFeesToReserve = "") {
        if (!value) {
            return 0
        }
        const nativeTokenSymbol = Utils.getNativeTokenSymbol(chainId)
        if (symbol !== nativeTokenSymbol || value === 0) {
            return value
        }

        let feeLowerLimit = 0.01
        let feeUpperLimit = 0.0001
        if(!Utils.isL1Chain(chainId)) {
            feeLowerLimit = 0.00001
            feeUpperLimit = 0.000000001 // 1GWei
        }

        let estFee = Math.max(feeUpperLimit, Math.min(feeLowerLimit, value * 0.1))
        if(!!cryptoFeesToReserve) {
            estFee = Utils.nativeTokenRawToDecimal(chainId, cryptoFeesToReserve)
        }

        const result = value - estFee

        // Ensure the result is not negative
        return Math.max(result, 0)
    }

    function getLabelForEstimatedTxTime(estimatedFlag) {
        switch(estimatedFlag) {
        case Constants.TransactionEstimatedTime.Unknown:
            return qsTr("~ Unknown")
        case Constants.TransactionEstimatedTime.LessThanOneMin :
            return qsTr("< 1 minute")
        case Constants.TransactionEstimatedTime.LessThanThreeMins :
            return qsTr("< 3 minutes")
        case Constants.TransactionEstimatedTime.LessThanFiveMins:
            return qsTr("< 5 minutes")
        default:
            return qsTr("> 5 minutes")
        }
    }

    function formatEstimatedTime(estimatedTime) {
        if (estimatedTime === 0 ) {
            return qsTr("Unknown")
        }
        if (estimatedTime >= 60) {
            return qsTr(">60s")
        }
        return qsTr("~%1s").arg(estimatedTime)
    }

    function getRouterErrorBasedOnCode(code) {
        if (code === "") {
            return ""
        }

        switch(code) {
        case Constants.routerErrorCodes.errInternal:
            return qsTr("an internal error occurred")
        case Constants.routerErrorCodes.errGeneric:
            return qsTr("unknown error occurred, try again later")
        case Constants.routerErrorCodes.processor.errFailedToParseBaseFee:
        case Constants.routerErrorCodes.processor.errFailedToParsePercentageFee:
        case Constants.routerErrorCodes.processor.errContractNotFound:
        case Constants.routerErrorCodes.processor.errNetworkNotFound:
        case Constants.routerErrorCodes.processor.errTokenNotFound:
        case Constants.routerErrorCodes.processor.errNoEstimationFound:
        case Constants.routerErrorCodes.processor.errNotAvailableForContractType:
        case Constants.routerErrorCodes.processor.errNoBonderFeeFound:
        case Constants.routerErrorCodes.processor.errContractTypeNotSupported:
        case Constants.routerErrorCodes.processor.errFromChainNotSupported:
        case Constants.routerErrorCodes.processor.errToChainNotSupported:
        case Constants.routerErrorCodes.processor.errTxForChainNotSupported:
        case Constants.routerErrorCodes.processor.errENSResolverNotFound:
        case Constants.routerErrorCodes.processor.errENSRegistrarNotFound:
        case Constants.routerErrorCodes.processor.errToAndFromTokensMustBeSet:
        case Constants.routerErrorCodes.processor.errCannotResolveTokens:
        case Constants.routerErrorCodes.processor.errPriceRouteNotFound:
        case Constants.routerErrorCodes.processor.errConvertingAmountToBigInt:
        case Constants.routerErrorCodes.processor.errNoChainSet:
        case Constants.routerErrorCodes.processor.errNoTokenSet:
        case Constants.routerErrorCodes.processor.errToTokenShouldNotBeSet:
        case Constants.routerErrorCodes.processor.errFromAndToChainsMustBeDifferent:
        case Constants.routerErrorCodes.processor.errFromAndToChainsMustBeSame:
        case Constants.routerErrorCodes.processor.errFromAndToTokensMustBeDifferent:
        case Constants.routerErrorCodes.processor.errContextCancelled:
        case Constants.routerErrorCodes.processor.errContextDeadlineExceeded:
        case Constants.routerErrorCodes.processor.errPriceTimeout:
        case Constants.routerErrorCodes.processor.errNotEnoughLiquidity:
        case Constants.routerErrorCodes.processor.errPriceImpactTooHigh:
            return qsTr("processor internal error")
        case Constants.routerErrorCodes.processor.errTransferCustomError:
        case Constants.routerErrorCodes.processor.errERC721TransferCustomError:
        case Constants.routerErrorCodes.processor.errERC1155TransferCustomError:
        case Constants.routerErrorCodes.processor.errBridgeHopCustomError:
        case Constants.routerErrorCodes.processor.errBridgeCellerCustomError:
        case Constants.routerErrorCodes.processor.errSwapParaswapCustomError:
        case Constants.routerErrorCodes.processor.errENSRegisterCustomError:
        case Constants.routerErrorCodes.processor.errENSReleaseCustomError:
        case Constants.routerErrorCodes.processor.errENSPublicKeyCustomError:
        case Constants.routerErrorCodes.processor.errStickersBuyCustomError:
            return qsTr("processor network error")
        case Constants.routerErrorCodes.router.errENSRegisterRequiresUsernameAndPubKey:
        case Constants.routerErrorCodes.router.errENSRegisterTestnetSTTOnly:
        case Constants.routerErrorCodes.router.errENSRegisterMainnetSNTOnly:
        case Constants.routerErrorCodes.router.errENSReleaseRequiresUsername:
        case Constants.routerErrorCodes.router.errENSSetPubKeyRequiresUsernameAndPubKey:
        case Constants.routerErrorCodes.router.errStickersBuyRequiresPackID:
        case Constants.routerErrorCodes.router.errSwapRequiresToTokenID:
        case Constants.routerErrorCodes.router.errSwapTokenIDMustBeDifferent:
        case Constants.routerErrorCodes.router.errSwapAmountInAmountOutMustBeExclusive:
        case Constants.routerErrorCodes.router.errSwapAmountInMustBePositive:
        case Constants.routerErrorCodes.router.errSwapAmountOutMustBePositive:
        case Constants.routerErrorCodes.router.errLockedAmountNotSupportedForNetwork:
        case Constants.routerErrorCodes.router.errLockedAmountNotNegative:
        case Constants.routerErrorCodes.router.errLockedAmountExceedsTotalSendAmount:
        case Constants.routerErrorCodes.router.errLockedAmountLessThanSendAmountAllNetworks:
        case Constants.routerErrorCodes.router.errNativeTokenNotFound:
        case Constants.routerErrorCodes.router.errDisabledChainFoundAmongLockedNetworks:
        case Constants.routerErrorCodes.router.errENSSetPubKeyInvalidUsername:
        case Constants.routerErrorCodes.router.errLockedAmountExcludesAllSupported:
        case Constants.routerErrorCodes.router.errTokenNotFound:
        case Constants.routerErrorCodes.router.errNoBestRouteFound:
        case Constants.routerErrorCodes.router.errCannotCheckReceiverBalance:
        case Constants.routerErrorCodes.router.errCannotCheckLockedAmounts:
            return qsTr("router network error")
        case Constants.routerErrorCodes.router.errNotEnoughTokenBalance:
            return qsTr("not enough token balance")
        case Constants.routerErrorCodes.router.errNotEnoughNativeBalance:
            return qsTr("Not enough ETH to pay gas fees")
        case Constants.routerErrorCodes.router.errLowAmountInForHopBridge:
            return qsTr("amount in too low")
        case Constants.routerErrorCodes.router.errNoPositiveBalance:
            return qsTr("no positive balance")
        default:
            return qsTr("unknown processor error")
        }
    }

    function getRouterErrorDetailsOnCode(code, details) {
        if (code === "") {
            return ""
        }

        switch(code) {
        case Constants.routerErrorCodes.errInternal:
        case Constants.routerErrorCodes.errGeneric:
            return details
        case Constants.routerErrorCodes.processor.errFailedToParseBaseFee:
            return qsTr("failed to parse base fee")
        case Constants.routerErrorCodes.processor.errFailedToParsePercentageFee:
            return qsTr("failed to parse percentage fee")
        case Constants.routerErrorCodes.processor.errContractNotFound:
            return qsTr("contract not found")
        case Constants.routerErrorCodes.processor.errNetworkNotFound:
            return qsTr("network not found")
        case Constants.routerErrorCodes.processor.errTokenNotFound:
            return qsTr("token not found")
        case Constants.routerErrorCodes.processor.errNoEstimationFound:
            return qsTr("no estimation found")
        case Constants.routerErrorCodes.processor.errNotAvailableForContractType:
            return qsTr("not available for contract type")
        case Constants.routerErrorCodes.processor.errNoBonderFeeFound:
            return qsTr("no bonder fee found")
        case Constants.routerErrorCodes.processor.errContractTypeNotSupported:
            return qsTr("contract type not supported")
        case Constants.routerErrorCodes.processor.errFromChainNotSupported:
            return qsTr("from chain not supported")
        case Constants.routerErrorCodes.processor.errToChainNotSupported:
            return qsTr("to chain not supported")
        case Constants.routerErrorCodes.processor.errTxForChainNotSupported:
            return qsTr("tx for chain not supported")
        case Constants.routerErrorCodes.processor.errENSResolverNotFound:
            return qsTr("ens resolver not found")
        case Constants.routerErrorCodes.processor.errENSRegistrarNotFound:
            return qsTr("ens registrar not found")
        case Constants.routerErrorCodes.processor.errToAndFromTokensMustBeSet:
            return qsTr("to and from tokens must be set")
        case Constants.routerErrorCodes.processor.errCannotResolveTokens:
            return qsTr("cannot resolve tokens")
        case Constants.routerErrorCodes.processor.errPriceRouteNotFound:
            return qsTr("price route not found")
        case Constants.routerErrorCodes.processor.errConvertingAmountToBigInt:
            return qsTr("converting amount issue")
        case Constants.routerErrorCodes.processor.errNoChainSet:
            return qsTr("no chain set")
        case Constants.routerErrorCodes.processor.errNoTokenSet:
            return qsTr("no token set")
        case Constants.routerErrorCodes.processor.errToTokenShouldNotBeSet:
            return qsTr("to token should not be set")
        case Constants.routerErrorCodes.processor.errFromAndToChainsMustBeDifferent:
            return qsTr("from and to chains must be different")
        case Constants.routerErrorCodes.processor.errFromAndToChainsMustBeSame:
            return qsTr("from and to chains must be same")
        case Constants.routerErrorCodes.processor.errFromAndToTokensMustBeDifferent:
            return qsTr("from and to tokens must be different")
        case Constants.routerErrorCodes.processor.errContextCancelled:
            return qsTr("context cancelled")
        case Constants.routerErrorCodes.processor.errContextDeadlineExceeded:
            return qsTr("context deadline exceeded")
        case Constants.routerErrorCodes.processor.errPriceTimeout:
            return qsTr("fetching price timeout")
        case Constants.routerErrorCodes.processor.errNotEnoughLiquidity:
            return qsTr("not enough liquidity")
        case Constants.routerErrorCodes.processor.errPriceImpactTooHigh:
            return qsTr("price impact too high")

        case Constants.routerErrorCodes.processor.errTransferCustomError:
        case Constants.routerErrorCodes.processor.errERC721TransferCustomError:
        case Constants.routerErrorCodes.processor.errERC1155TransferCustomError:
        case Constants.routerErrorCodes.processor.errBridgeHopCustomError:
        case Constants.routerErrorCodes.processor.errBridgeCellerCustomError:
        case Constants.routerErrorCodes.processor.errSwapParaswapCustomError:
        case Constants.routerErrorCodes.processor.errENSRegisterCustomError:
        case Constants.routerErrorCodes.processor.errENSReleaseCustomError:
        case Constants.routerErrorCodes.processor.errENSPublicKeyCustomError:
        case Constants.routerErrorCodes.processor.errStickersBuyCustomError:
            return details
        case Constants.routerErrorCodes.router.errENSRegisterRequiresUsernameAndPubKey:
            return qsTr("username and public key are required for registering ens name")
        case Constants.routerErrorCodes.router.errENSRegisterTestnetSTTOnly:
            return qsTr("only STT is supported for registering ens name on testnet")
        case Constants.routerErrorCodes.router.errENSRegisterMainnetSNTOnly:
            return qsTr("only SNT is supported for registering ens name on mainnet")
        case Constants.routerErrorCodes.router.errENSReleaseRequiresUsername:
            return qsTr("username is required for releasing ens name")
        case Constants.routerErrorCodes.router.errENSSetPubKeyRequiresUsernameAndPubKey:
            return qsTr("username and public key are required for setting public key")
        case Constants.routerErrorCodes.router.errStickersBuyRequiresPackID:
            return qsTr("stickers pack id is required for buying stickers")
        case Constants.routerErrorCodes.router.errSwapRequiresToTokenID:
            return qsTr("to token is required for Swap")
        case Constants.routerErrorCodes.router.errSwapTokenIDMustBeDifferent:
            return qsTr("from and to token must be different")
        case Constants.routerErrorCodes.router.errSwapAmountInAmountOutMustBeExclusive:
            return qsTr("only one of amount to send or receiving amount can be set")
        case Constants.routerErrorCodes.router.errSwapAmountInMustBePositive:
            return qsTr("amount to send must be positive")
        case Constants.routerErrorCodes.router.errSwapAmountOutMustBePositive:
            return qsTr("receiving amount must be positive")
        case Constants.routerErrorCodes.router.errLockedAmountNotSupportedForNetwork:
            return qsTr("locked amount is not supported for the selected network")
        case Constants.routerErrorCodes.router.errLockedAmountNotNegative:
            return qsTr("locked amount must not be negative")
        case Constants.routerErrorCodes.router.errLockedAmountExceedsTotalSendAmount:
            return qsTr("locked amount exceeds the total amount to send")
        case Constants.routerErrorCodes.router.errLockedAmountLessThanSendAmountAllNetworks:
            return qsTr("locked amount is less than the total amount to send, but all networks are locked")
        case Constants.routerErrorCodes.router.errNativeTokenNotFound:
            return qsTr("native token not found")
        case Constants.routerErrorCodes.router.errDisabledChainFoundAmongLockedNetworks:
            return qsTr("disabled chain found among locked networks")
        case Constants.routerErrorCodes.router.errENSSetPubKeyInvalidUsername:
            return qsTr("a valid username, ending in '.eth', is required for setting public key")
        case Constants.routerErrorCodes.router.errLockedAmountExcludesAllSupported:
            return qsTr("all supported chains are excluded, routing impossible")
        case Constants.routerErrorCodes.router.errTokenNotFound:
            return qsTr("token not found")
        case Constants.routerErrorCodes.router.errNoBestRouteFound:
            return qsTr("no best route found")
        case Constants.routerErrorCodes.router.errCannotCheckReceiverBalance:
            return qsTr("cannot check balance")
        case Constants.routerErrorCodes.router.errCannotCheckLockedAmounts:
            return qsTr("cannot check locked amounts")
        case Constants.routerErrorCodes.router.errNotEnoughTokenBalance:
            try {
                const jsonObj = JSON.parse(details)

                let chain = Utils.getNetworkName(jsonObj.chainId)
                return qsTr("not enough balance for %1 on %2 chain").arg(jsonObj.token).arg(chain)
            }
            catch (e) {
                return ""
            }
        case Constants.routerErrorCodes.router.errNotEnoughNativeBalance:
            return details
        case Constants.routerErrorCodes.router.errLowAmountInForHopBridge:
            return qsTr("bonder fee greater than estimated received, a higher amount is needed to cover fees")
        case Constants.routerErrorCodes.router.errNoPositiveBalance:
            return qsTr("no positive balance for your account across chains")
        default:
            return ""
        }
    }

    function getFeeTextForFeeMode(feeMode) {
        switch(feeMode) {
        case Constants.FeePriorityModeType.Fast:
            return qsTr("Fast")
        case Constants.FeePriorityModeType.Urgent:
            return qsTr("Urgent")
        case Constants.FeePriorityModeType.Custom:
            return qsTr("Custom")
        case Constants.FeePriorityModeType.Normal:
        default:
            return qsTr("Normal")
        }
    }

    function getIconForFeeMode(feeMode) {
        switch(feeMode) {
        case Constants.FeePriorityModeType.Fast:
            return Assets.png("wallet/car")
        case Constants.FeePriorityModeType.Urgent:
            return Assets.png("wallet/rocket")
        case Constants.FeePriorityModeType.Custom:
            return Assets.png("wallet/handwrite")
        case Constants.FeePriorityModeType.Normal:
        default:
            return Assets.png("wallet/clock")
        }
    }

    function getChangePct24HourColor(palette, changePct24hour) {
        if (changePct24hour === 0)
            return palette.baseColor1
        return changePct24hour < 0
                ? palette.dangerColor1
                : palette.successColor1
    }

    function getUpDownTriangle(changePct24hour) {
        if (changePct24hour === 0)
            return ""
        return changePct24hour < 0 ? "▾" : "▴"
    }
}
