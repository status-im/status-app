import QtQuick

import utils

/* This is so that all the data from the response
to the swap request can be placed here at one place. */
QtObject {
    id: root

    property string fromTokenAmount: ""
    property string toTokenAmount: ""
    // TODO: this should be string but backend gas_estimate_item.nim passes this as float
    property real totalFees: 0

    property string txFeesWei: "0"
    property real txFeesInFiat: 0
    property string approvalTxFeesWei: "0"
    property real approvalTxFeesFiat: 0

    property string maxFeesToReserveRaw: ""
    property bool hasError
    property string errCode
    property string errDescription
    property var rawPaths: []
    // need to check how this is done in new router v2, right now it is Enum type
    property int estimatedTime
    property string txProviderName
    property string txProviderTool
    property bool approvalNeeded
    property string approvalGasFees
    property string approvalAmountRequired
    property string approvalContractAddress

    function resetPathInfoAndError() {
        root.hasError = false
        root.errCode = ""
        root.errDescription = ""
        root.rawPaths = []
    }

    function reset() {
        root.fromTokenAmount = ""
        root.toTokenAmount = ""
        root.txProviderName = ""
        root.txProviderTool = ""
        root.estimatedTime = Constants.TransactionEstimatedTime.Unknown
        root.totalFees = 0
        root.maxFeesToReserveRaw = 0
        root.approvalNeeded = false
        root.approvalGasFees = ""
        root.approvalAmountRequired = ""
        root.approvalContractAddress = ""
        root.txFeesWei = "0"
        root.txFeesInFiat = 0
        root.approvalTxFeesWei = "0"
        root.approvalTxFeesFiat = 0
        resetPathInfoAndError()
    }
}

