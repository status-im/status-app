import QtQuick
import QtTest

import shared.controls
import shared.stores as SharedStores

import Models
import utils

Item {
    id: root

    width: 800
    height: 200

    property bool nameRecipient: true

    readonly property string recipient: "0x3fb81384583b3910BB14Cc72582E8e8a56E83ae9"
    readonly property string sender: "0xfB8131c260749c7835a08ccBdb64728De432858E"

    QtObject {
        id: activity

        function getNameForAddress(address) {
            if (root.nameRecipient && address === root.recipient)
                return "Account 1"
            return ""
        }

        function getTransactionType(transaction) {
            if (!transaction || transaction.txType === undefined)
                return Constants.TransactionType.Send
            return transaction.txType
        }
    }

    QtObject {
        id: tx

        readonly property string id: "0xdeadbeef"
        readonly property int timestamp: 1714059810
        readonly property int status: Constants.TransactionStatus.Complete
        readonly property double amount: 1
        readonly property double inAmount: 1
        readonly property double outAmount: 1
        readonly property string symbol: "ETH"
        readonly property string inSymbol: "ETH"
        readonly property string outSymbol: "ETH"
        readonly property bool isMultiTransaction: false
        readonly property int txType: Constants.TransactionType.Send
        readonly property string sender: root.sender
        readonly property string recipient: root.recipient
        readonly property bool isNFT: false
        readonly property string communityId: ""
        readonly property string tokenAddress: "0x0000000000000000000000000000000000000000"
        readonly property string tokenInAddress: ""
        readonly property string tokenOutAddress: ""
        readonly property int chainId: 1
        readonly property int chainIdIn: 1
        readonly property int chainIdOut: 1
        readonly property string interactedContractAddress: ""
        readonly property string approvalSpender: ""
    }

    Component {
        id: delegateComponent

        TransactionDelegate {
            width: 600
            modelData: tx
            flatNetworks: NetworksModel.flatNetworks
            activityStore: activity
            currenciesStore: SharedStores.CurrenciesStore {
                readonly property string currentCurrency: "USD"

                function getFiatValue(cryptoValue, symbol) {
                    return cryptoValue
                }

                function formatCurrencyAmount(cryptoValue, symbol) {
                    return cryptoValue + " " + symbol
                }
            }
        }
    }

    TestCase {
        name: "TransactionDelegate"
        when: windowShown

        function test_toAddress_usesAccountNameOrCompactAddress() {
            root.nameRecipient = true
            const delegate = createTemporaryObject(delegateComponent, root)
            waitForRendering(delegate)

            compare(delegate.toAddress, "Account 1")

            root.nameRecipient = false
            compare(delegate.toAddress, Utils.compactAddress(root.recipient, 4))
        }
    }
}
