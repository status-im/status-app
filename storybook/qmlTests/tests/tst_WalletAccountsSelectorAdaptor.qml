import QtQuick
import QtTest

import StatusQ
import StatusQ.Core.Utils

import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors

import shared.stores
import utils

import QtModelsToolkit
import SortFilterProxyModel

import Models
import Mocks

Item {
    id: root
    width: 600
    height: 400

    readonly property string ethGroupKey: Constants.ethGroupKey
    readonly property string sttGroupKey: Constants.sttGroupKey

    ListModel {
        id: walletAccountsModel
        readonly property var data: [
            {
                name: "helloworld",
                address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                emoji: "😋",
                colorId: Constants.walletAccountColors.primary,
                walletType: "",
                canSend: true,
                position: 0,
                currencyBalance: ({amount: 1.25,
                                      symbol: "USD",
                                      displayDecimals: 2,
                                      stripTrailingZeroes: false}),
                migratedToColdWallet: true
            },
            {
                name: "Hot wallet (generated)",
                emoji: "🚗",
                colorId: Constants.walletAccountColors.army,
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                walletType: Constants.generatedWalletType,
                canSend: true,
                position: 3,
                currencyBalance: ({amount: 10,
                                      symbol: "USD",
                                      displayDecimals: 2,
                                      stripTrailingZeroes: false}),
                migratedToColdWallet: false
            },
            {
                name: "Family (seed)",
                emoji: "🎨",
                colorId: Constants.walletAccountColors.magenta,
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882",
                walletType: Constants.seedWalletType,
                canSend: true,
                position: 1,
                currencyBalance: ({amount: 110.05,
                                      symbol: "USD",
                                      displayDecimals: 2,
                                      stripTrailingZeroes: false}),
                migratedToColdWallet: false
            },
            {
                name: "Tag Heuer (watch)",
                emoji: "⌚",
                colorId: Constants.walletAccountColors.copper,
                color: "#CB6256",
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8883",
                walletType: Constants.watchWalletType,
                canSend: false,
                position: 2,
                currencyBalance: ({amount: 3,
                                      symbol: "USD",
                                      displayDecimals: 2,
                                      stripTrailingZeroes: false}),
                migratedToColdWallet: false
            },
            {
                name: "Fab (key)",
                emoji: "🔑",
                colorId: Constants.walletAccountColors.camel,
                color: "#C78F67",
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                walletType: Constants.keyWalletType,
                canSend: true,
                position: 4,
                currencyBalance: ({amount: 999,
                                      symbol: "USD",
                                      displayDecimals: 2,
                                      stripTrailingZeroes: false}),
                migratedToColdWallet: false
            }
        ]

        Component.onCompleted: append(data)
    }

    QtObject {
        id: d

        readonly property var flatNetworks: NetworksModel.flatNetworks
        readonly property var assetsStore: WalletAssetsStoreMock {
            id: thisWalletAssetStore
            walletTokensStore: TokensStoreMock {
                tokenGroupsModel: TokenGroupsModel {}
            }
        }

        readonly property var currencyStore: CurrenciesStore{}
        readonly property var nonWatchWalletAcounts: SortFilterProxyModel {
            sourceModel: walletAccountsModel
            filters: ValueFilter { roleName: "canSend"; value: true }
        }

        readonly property var filteredFlatNetworksModel: SortFilterProxyModel {
            sourceModel: d.flatNetworks
            filters: ValueFilter { roleName: "isTest"; value: true }
        }

        readonly property ObjectProxyModel filteredBalancesModel: ObjectProxyModel {
            sourceModel: d.assetsStore.groupedAccountAssetsModel

            delegate: SortFilterProxyModel {
                readonly property var balances: this

                sourceModel: LeftJoinModel {
                    leftModel: model.balances
                    rightModel: d.filteredFlatNetworksModel

                    joinRole: "chainId"
                }

                filters: ValueFilter {
                    roleName: "chainId"
                    value: d.selectedNetworkChainId
                }
            }

            expectedRoles: "balances"
            exposedRoles: "balances"
        }

        property string selectedGroupKey: ethGroupKey
        property int selectedNetworkChainId: 11155111
    }

    Component {
        id: componentUnderTest
        WalletAccountsSelectorAdaptor {
            accounts: walletAccountsModel
            assetsModel: d.assetsStore.groupedAccountAssetsModel
            tokenGroupsModel: d.assetsStore.walletTokensStore.tokenGroupsModel
            filteredFlatNetworksModel: d.filteredFlatNetworksModel

            selectedGroupKey: d.selectedGroupKey
            selectedNetworkChainId: d.selectedNetworkChainId

            fnFormatCurrencyAmountFromBigInt: function(balance, symbol, decimals, options = null) {
                return d.currencyStore.formatCurrencyAmountFromBigInt(balance, symbol, decimals, options)
            }
        }
    }

    property WalletAccountsSelectorAdaptor controlUnderTest: null

    TestCase {
        name: "WalletAccountsSelectorAdaptor"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_no_watchOnly_account() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.processedWalletAccounts.count, d.nonWatchWalletAcounts.count)
        }

        function test_accountBalance_data() {
            return [
                        {selectedGroupKey: ethGroupKey, chainId: 11155111},
                        {selectedGroupKey: sttGroupKey, chainId: 11155111},
                        {selectedGroupKey: ethGroupKey, chainId: 11155420},
                        {selectedGroupKey: sttGroupKey, chainId: 11155420}
                    ]
        }

        function test_accountBalance(data) {
            verify(!!controlUnderTest)
            d.selectedGroupKey = data.selectedGroupKey
            d.selectedNetworkChainId = data.chainId
            let processedAccounts = controlUnderTest.processedWalletAccounts
            for (let i = 0; i < processedAccounts.count; i++) {
                let accountAddress = processedAccounts.get(i).address
                let selectedTokenBalancesModel = ModelUtils.getByKey(d.filteredBalancesModel, "key", d.selectedGroupKey).balances
                let tokenBalanceForSelectedAccount = ModelUtils.getByKey(selectedTokenBalancesModel, "account", accountAddress) ?? 0
                let tokenBalanceForAccount =  !!tokenBalanceForSelectedAccount ? tokenBalanceForSelectedAccount.balance: "0"

                compare(tokenBalanceForAccount, processedAccounts.get(i).accountBalance.balance)
            }
        }
    }
}
