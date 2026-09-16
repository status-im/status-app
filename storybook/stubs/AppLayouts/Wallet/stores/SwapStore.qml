import QtQml

QtObject {
    id: root

    property var accounts

    signal suggestedRoutesReady(var txRoutes, string errCode, string errDescription)
    signal transactionSent(var uuid, var chainId, var approvalTx, var txHash, var error)
    signal transactionSendingComplete(var txHash,  var success)
}
