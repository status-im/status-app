import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Wallet.adaptors

import Models
import utils

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: adaptorComp

        SignSendAdaptor {
            palette: Theme.palette
            accountKey: ""
            chainId: 1
            groupKey: Constants.ethGroupKey
            selectedAmountInBaseUnit: ""
            selectedRecipientAddress: ""
            accountsModel: ListModel {}
            networksModel: ListModel {}
            tokenGroupsModel: TokenGroupsModel {}
            recipientModel: ListModel {}
        }
    }

    TestCase {
        name: "SignSendAdaptor"
        when: windowShown

        function test_emptyRawAmount_returnsZero() {
            const adaptor = createTemporaryObject(adaptorComp, root)
            compare(adaptor.selectedAmount, "0")
            compare(adaptor.selectedAsset.symbol, Constants.ethToken)
        }

        function test_missingDecimalsAndInvalidRaw_returnsZero() {
            const adaptor = createTemporaryObject(adaptorComp, root, {
                groupKey: "no-decimals",
                selectedAmountInBaseUnit: "not-a-number",
                tokenGroupsModel: dummyTokens
            })
            compare(adaptor.selectedAmount, "0")
        }
    }

    ListModel {
        id: dummyTokens
        Component.onCompleted: append([{ key: "no-decimals", symbol: "XYZ", logoUri: "", tokens: [] }])
    }
}
