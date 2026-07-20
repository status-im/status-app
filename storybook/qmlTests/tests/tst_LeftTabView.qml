import QtQuick
import QtTest

import AppLayouts.Wallet.views

import utils

Item {
    id: root

    width: 600
    height: 600

    ListModel {
        id: accountsModel
    }

    LeftTabViewState {
        id: leftTabViewState

        accountsModel: accountsModel
        totalCurrencyBalance: ({
            amount: 0,
            symbol: "USD",
            displayDecimals: 2,
            stripTrailingZeroes: false
        })
        balanceLoading: false
        selectedAddress: ""
    }

    Component {
        id: componentUnderTest

        LeftTabView {
            objectName: "walletLeftTab"

            anchors.fill: parent
            viewState: leftTabViewState
        }
    }

    TestCase {
        name: "LeftTabView"
        when: windowShown

        property var controlUnderTest: null

        function account(name, emoji, colorId, position) {
            return {
                name,
                address: "0x%1".arg(position.toString().padStart(40, "0")),
                emoji,
                colorId,
                position,
                walletType: "",
                migratedToColdWallet: false,
                currencyBalance: ({
                    amount: 0,
                    symbol: "USD",
                    displayDecimals: 2,
                    stripTrailingZeroes: false
                }),
                assetsLoading: false,
                hideFromTotalBalance: false
            }
        }

        function cleanup() {
            if (!!controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
        }

        function syncPositions() {
            for (let i = 0; i < accountsModel.count; ++i)
                accountsModel.setProperty(i, "position", i)
        }

        function verifyWalletOrder(expectedTitles) {
            const listView = findChild(controlUnderTest, "walletAccountsListView")
            verify(!!listView)
            waitForRendering(listView)
            tryVerify(() => {
                if (listView.count !== expectedTitles.length)
                    return false
                for (let i = 0; i < expectedTitles.length; ++i) {
                    const item = listView.itemAtIndex(i)
                    if (!item || item.title !== expectedTitles[i])
                        return false
                }
                return true
            })
        }

        function createView(accountData) {
            cleanup()

            accountsModel.clear()
            for (let i = 0; i < accountData.length; ++i)
                accountsModel.append(accountData[i])

            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function test_reflectsAccountsModelOrder() {
            createView([
                account("Account 1", "😀", Constants.walletAccountColors.primary, 0),
                account("Generated 1", "😎", Constants.walletAccountColors.army, 1),
                account("Generated 2", "👍", Constants.walletAccountColors.magenta, 2)
            ])

            verifyWalletOrder(["Account 1", "Generated 1", "Generated 2"])

            accountsModel.move(0, 2, 1)
            syncPositions()
            verifyWalletOrder(["Generated 1", "Generated 2", "Account 1"])

            accountsModel.move(1, 0, 1)
            syncPositions()
            verifyWalletOrder(["Generated 2", "Generated 1", "Account 1"])
        }
    }
}
