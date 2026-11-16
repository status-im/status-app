import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog
import QtModelsToolkit
import SortFilterProxyModel
import AppLayouts.Browser.provider.qml
import AppLayouts.Wallet
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types
import shared.popups.walletconnect
import utils

// Loaded by URL (see DAppsWorkflow), so DAppSignRequestModal is not loaded with the wallet
DAppSignRequestModal {
    id: dappRequestModal
    objectName: "dappsRequestModal"

    required property var host // DAppsWorkflow
    required property var model
    required property int index

    readonly property var request: model.requestItem
    readonly property var account: accountEntry.available ? accountEntry.item : {
        name: "",
        address: "",
        emoji: "",
        colorId: 0,
        keyUid: "",
        migratedToColdWallet: false
    }

    readonly property var network: networkEntry.available ? networkEntry.item : {
        chainName: "",
        iconUrl: ""
    }
    property bool requestHandled: false

    function rejectRequest() {
        // Allow rejecting only once
        if (requestHandled) {
            return
        }
        requestHandled = true
        dappRequestModal.host.signRequestRejected(request.topic, request.requestId)
    }

    parent: dappRequestModal.host.visualParent

    keyUid: account.keyUid
    migratedToColdWallet: account.migratedToColdWallet
    formatBigNumber: dappRequestModal.host.formatBigNumber

    visible: !!request.dappUrl

    dappUrl: request.dappUrl
    dappIcon: request.dappIcon
    dappName: request.dappName

    accountColor: Utils.getColorForId(Theme.palette, account.colorId)
    accountName: account.name
    accountAddress: account.address
    accountEmoji: account.emoji

    networkName: network.chainName
    networkIconPath: Assets.svg(network.iconUrl)

    fiatFees: request.fiatMaxFees ? request.fiatMaxFees.toFixed() : ""
    fiatSymbol: request.fiatSymbol
    cryptoFees: request.nativeTokenMaxFees ? request.nativeTokenMaxFees.toFixed() : ""
    nativeTokenSymbol: Utils.getNativeTokenSymbol(request.chainId)
    estimatedTime: WalletUtils.getLabelForEstimatedTxTime(request.estimatedTimeCategory)
    feesLoading: hasFees && (!fiatFees || !cryptoFees) && !gasEstimateFailed
    estimatedTimeLoading: request.estimatedTimeCategory === Constants.TransactionEstimatedTime.Unknown
    hasFees: signingTransaction
    enoughFundsForTransaction: request.haveEnoughFunds
    enoughFundsForFees: request.haveEnoughFees
    gasEstimateFailed: !!request.gasEstimateFailed

    // the gas to sign is known once our estimate answered
    signButtonEnabled: ((!hasFees) || enoughFundsForTransaction && enoughFundsForFees && !!request.gasLimit) && dappRequestModal.host.enabled
    signingTransaction: !!request.method && (request.method === SessionRequest.methods.signTransaction.name
                                          || request.method === SessionRequest.methods.sendTransaction.name)
    requestPayload: {
        try {
            const data = JSON.parse(request.preparedData)

            delete data.maxFeePerGas
            delete data.maxPriorityFeePerGas
            delete data.gasPrice

            return JSON.stringify(data, null, 2)
        } catch(_) {
            return request.preparedData
        }
    }
    expirationSeconds: request.expirationTimestamp ? request.expirationTimestamp - requestTimestamp.getTime() / 1000
                                                    : 0
    hasExpiryDate: !!request.expirationTimestamp

    onOpened: {
        dappRequestModal.host.signRequestIsLive(request.topic, request.requestId)
    }

    onClosed: {
        Qt.callLater(rejectRequest)
    }

    onAccepted: {
        requestHandled = true
        dappRequestModal.host.signRequestAccepted(request.topic, request.requestId)
    }

    onRejected: {
        rejectRequest()
    }

    ModelEntry {
        id: accountEntry
        sourceModel: dappRequestModal.host.accountsModel
        key: "address"
        value: dappRequestModal.request.accountAddress
    }

    ModelEntry {
        id: networkEntry
        sourceModel: dappRequestModal.host.networksModel
        key: "chainId"
        value: dappRequestModal.request.chainId
    }
}
