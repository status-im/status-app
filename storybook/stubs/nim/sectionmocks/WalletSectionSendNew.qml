// Mock of src/app/modules/main/wallet_section/send_new/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionSendNew"

    signal signingRequested(string keyUid, string txHash, string path, string address)
    signal suggestedRoutesReady(string uuid, var pathModel, string errCode, string errDescription)
    signal transactionSendingComplete(string txHash, string status)
    signal transactionSent(string uuid, int chainId, bool approvalTx, string txHash, string error)
    signal successfullyAuthenticated(string uuid)

    // Last call of each kind, so a page or test can assert what was requested.
    property var lastRouteRequest: null
    property var lastTransferRequest: null

    function fetchSuggestedRoutes(uuid, sendType, chainId, accountFrom, accountTo, amountIn, token,
                                  amountOut, toToken, slippagePercentage, extraParamsJson) {
        root.lastRouteRequest = ({
            uuid: uuid, sendType: sendType, chainId: chainId, accountFrom: accountFrom,
            accountTo: accountTo, amountIn: amountIn, token: token, amountOut: amountOut,
            toToken: toToken, slippagePercentage: slippagePercentage
        })
    }

    function resetData() {}

    function authenticateAndTransfer(uuid, fromAddr) {
        root.lastTransferRequest = ({ uuid: uuid, fromAddr: fromAddr })
        root.successfullyAuthenticated(uuid)
    }

    function onSigningResult(signature) {}
    function setFeeMode(feeMode, routerInputParamsUuid, pathName, chainId, isApprovalTx, communityId) {}
    function setCustomTxDetails(nonce, gasAmount, gasPrice, maxFeesPerGas, priorityFee,
                                routerInputParamsUuid, pathName, chainId, isApprovalTx, communityId) {}
    function getEstimatedTime(chainId, gasPrice, maxFeesPerGas, priorityFee) { return 30 }
}
