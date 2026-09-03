import QtQuick
import QtTest

import AppLayouts.Wallet.adaptors

import StatusQ.Core.Theme

Item {
    id: root

    Component {
        id: testComponent

        SignSendAdaptor {
            palette: Theme.palette

            accountKey: "0x1"
            chainId: 1
            groupKey: "eth"
            selectedAmountInBaseUnit: ""
            selectedRecipientAddress: "0x2"

            accountsModel: ListModel {
                Component.onCompleted: append([
                    { address: "0x1", name: "Account 1", emoji: "🚀", colorId: "army" }
                ])
            }
            networksModel: ListModel {
                Component.onCompleted: append([
                    { chainId: 1, chainName: "Mainnet", iconUrl: "network/ethereum" }
                ])
            }
            tokenGroupsModel: ListModel {
                Component.onCompleted: append([
                    {
                        key: "eth", symbol: "ETH", decimals: 18,
                        tokens: [ { chainId: 1, address: "0xeth" } ]
                    }
                ])
            }
            recipientModel: ListModel {
                Component.onCompleted: append([
                    { address: "0x2", name: "Bob", ens: "", emoji: "", color: "", colorId: "" }
                ])
            }
        }
    }

    TestCase {
        name: "SignSendAdaptor"
        when: windowShown

        property SignSendAdaptor controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(testComponent, root)
            verify(!!controlUnderTest)
        }

        // The send modal feeds an empty raw amount until the user types one, so
        // the adaptor is built and rebound in that state on every open.
        function test_selectedAmount_noAmountEntered() {
            compare(controlUnderTest.selectedAmount, "")
        }

        // ModelEntry.item is an always-present (possibly empty) property map, so
        // the asset's decimals must be read through `available`, not truthiness.
        function test_selectedAmount_unresolvedAsset() {
            controlUnderTest.groupKey = "not-in-the-model"
            controlUnderTest.selectedAmountInBaseUnit = "1500000000000000000"
            compare(controlUnderTest.selectedAmount, "")
        }

        function test_selectedAmount_resolvedAsset() {
            controlUnderTest.selectedAmountInBaseUnit = "1500000000000000000"
            compare(controlUnderTest.selectedAmount,
                    "1" + Qt.locale().decimalPoint + "5")
        }

        function test_selectedAmount_wholeNumberStripsZeros() {
            controlUnderTest.selectedAmountInBaseUnit = "2000000000000000000"
            compare(controlUnderTest.selectedAmount, "2")
        }
    }
}
