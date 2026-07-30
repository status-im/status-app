import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet
import AppLayouts.Wallet.views

import StatusQ.Core.Theme

import utils

Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: accountsModel
    }

    LeftTabViewState {
        id: panelState

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

        Item {
            id: wrapper

            property var accountsModel

            width: parent.width
            height: parent.height

            AccountOrderView {
                id: accountOrderView
                objectName: "accountOrderView"

                anchors.top: parent.top
                anchors.left: parent.left
                width: parent.width - walletView.width
                accountsModel: wrapper.accountsModel
            }

            LeftTabView {
                id: walletView
                objectName: "walletLeftTab"

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
                width: 300
                viewState: panelState
            }
        }
    }

    TestCase {
        name: "AccountOrderSync"
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

        function syncPositions() {
            for (let i = 0; i < accountsModel.count; ++i)
                accountsModel.setProperty(i, "position", i)
        }

        function accountOrderView() {
            return findChild(controlUnderTest, "accountOrderView")
        }

        function walletView() {
            return findChild(controlUnderTest, "walletLeftTab")
        }

        function delegateAt(index) {
            return findChild(accountOrderView(), "accountOrderDelegate-%1".arg(index))
        }

        function verifyWalletOrder(expectedTitles) {
            const listView = findChild(walletView(), "walletAccountsListView")
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

        function verifyOrder(expectedTitles) {
            for (let i = 0; i < expectedTitles.length; ++i)
                tryCompare(delegateAt(i), "title", expectedTitles[i])
            verifyWalletOrder(expectedTitles)
        }

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
        }

        function createView(accountData) {
            cleanup()

            accountsModel.clear()
            for (let i = 0; i < accountData.length; ++i)
                accountsModel.append(accountData[i])

            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                width: root.width,
                height: root.height,
                accountsModel: accountsModel
            })
            verify(!!controlUnderTest)

            const orderView = accountOrderView()
            verify(!!orderView)

            orderView.moveAccountRequested.connect(function(from, to) {
                accountsModel.move(from, to, 1)
            })
            orderView.moveAccountFinallyRequested.connect(function() {
                syncPositions()
            })

            waitForRendering(controlUnderTest)

            const accountsList = findChild(orderView, "accountOrderList")
            verify(!!accountsList)
            tryCompare(accountsList, "count", accountData.length)
        }

        function test_dragInAccountOrderViewReflectsInLeftTabView() {
            createView([
                account("Account 1", "😀", Constants.walletAccountColors.primary, 0),
                account("Generated 1", "😎", Constants.walletAccountColors.army, 1),
                account("Generated 2", "👍", Constants.walletAccountColors.magenta, 2)
            ])

            verifyOrder(["Account 1", "Generated 1", "Generated 2"])

            let delegate = delegateAt(0)
            waitForRendering(delegate)
            mouseDrag(delegate, delegate.width / 2, delegate.height / 2,
                      0, delegate.height * 2)

            verifyOrder(["Generated 1", "Generated 2", "Account 1"])

            delegate = delegateAt(1)
            waitForRendering(delegate)
            mouseDrag(delegate, delegate.width / 2, delegate.height / 2,
                      0, -delegate.height)

            verifyOrder(["Generated 2", "Generated 1", "Account 1"])
        }
    }
}
