import QtQuick
import QtTest

import AppLayouts.Wallet.views

import StatusQ.Core

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
        totalCurrencyBalance: root.usdAmount(0)
        balanceLoading: false
        selectedAddress: ""
    }

    function usdAmount(amount) {
        return {
            amount: amount,
            symbol: "USD",
            displayDecimals: 2,
            stripTrailingZeroes: false
        }
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

        property LeftTabView controlUnderTest: null

        function account(name, emoji, colorId, position, extra) {
            extra = extra || {}
            return {
                name,
                address: extra.address || "0x%1".arg(position.toString().padStart(40, "0")),
                emoji,
                colorId,
                position,
                walletType: extra.walletType || "",
                migratedToColdWallet: false,
                currencyBalance: extra.currencyBalance || root.usdAmount(0),
                assetsLoading: false,
                hideFromTotalBalance: extra.hideFromTotalBalance || false
            }
        }

        function watchedAccount(hideFromTotalBalance, balance) {
            return account("Watched", "👀", Constants.walletAccountColors.primary, 0, {
                walletType: Constants.watchWalletType,
                hideFromTotalBalance: hideFromTotalBalance,
                currencyBalance: balance
            })
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
            tryVerify(() => !!findChild(controlUnderTest, "walletAccountsListView"))
            const listView = findChild(controlUnderTest, "walletAccountsListView")
            waitForRendering(listView)
            tryVerify(() => {
                if (listView.count !== expectedTitles.length)
                    return false
                for (let i = 0; i < expectedTitles.length; ++i) {
                    const row = listView.itemAtIndex(i)?.contentItem
                    if (!row || row.title !== expectedTitles[i])
                        return false
                }
                return true
            })
        }

        function createView(accountData, totalBalance) {
            cleanup()

            accountsModel.clear()
            for (let i = 0; i < accountData.length; ++i)
                accountsModel.append(accountData[i])

            leftTabViewState.totalCurrencyBalance = totalBalance || root.usdAmount(0)

            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function accountRow(index) {
            tryVerify(() => !!findChild(controlUnderTest, "walletAccountsListView"))
            const listView = findChild(controlUnderTest, "walletAccountsListView")
            waitForRendering(listView)
            tryVerify(() => !!listView.itemAtIndex(index)?.contentItem)
            return listView.itemAtIndex(index).contentItem
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

        function test_watchAccountSubtitleRespectsHideFromTotalBalance() {
            const balance = root.usdAmount(12.5)

            createView([watchedAccount(true, balance)])
            compare(accountRow(0).subTitle, "")

            createView([watchedAccount(false, balance)])
            compare(accountRow(0).subTitle, LocaleUtils.currencyAmountToLocaleString(balance))
        }

        function test_allAccountsHeaderShowsTotalCurrencyBalance() {
            const total = root.usdAmount(99.5)
            createView([
                account("Account 1", "😀", Constants.walletAccountColors.primary, 0)
            ], total)

            tryVerify(() => !!findChild(controlUnderTest, "walletLeftListAmountValue"))
            const amountLabel = findChild(controlUnderTest, "walletLeftListAmountValue")
            compare(amountLabel.text,
                    LocaleUtils.currencyAmountToLocaleString(total, {noSymbol: true}))
        }
    }
}
