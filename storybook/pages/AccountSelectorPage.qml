import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel

import shared.controls
import shared.stores

import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors

import utils

import Models
import Mocks

SplitView {
    id: root

    orientation: Qt.Vertical

    QtObject {
        id: d

        readonly property var flatNetworks: NetworksModel.flatNetworks
        readonly property var assetsStore: WalletAssetsStoreMock {
            id: thisWalletAssetStore
            walletTokensStore: TokensStoreMock {
                tokenGroupsModel: TokenGroupsModel {}
            }
            readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
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
    }

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

    WalletAccountsSelectorAdaptor {
        id: walletAccountsSelectorAdaptor

        accounts: walletAccountsModel
        assetsModel: d.assetsStore.groupedAccountAssetsModel
        tokenGroupsModel: d.assetsStore.walletTokensStore.tokenGroupsModel
        filteredFlatNetworksModel: d.filteredFlatNetworksModel

        selectedGroupKey: selectedTokenComboBox.currentValue ?? ""
        selectedNetworkChainId: networksComboBox.currentValue ?? -1

        fnFormatCurrencyAmountFromBigInt: function(balance, symbol, decimals, options = null) {
            return d.currencyStore.formatCurrencyAmountFromBigInt(balance, symbol, decimals, options)
        }
    }

    Item {
        SplitView.preferredWidth: 150
        SplitView.fillHeight: true
        ColumnLayout {
            spacing: 16
            width: 150

            WalletAccountsModel {
                id: accountsModel
            }

            Label {
                text: "Default style"
                font.bold: true
                Layout.fillWidth: true
            }
            AccountSelector {
                id: accountSelector
                Layout.fillWidth: true
                model: WalletAccountsModel {}
                onCurrentAccountAddressChanged: {
                    accountSelector2.selectedAddress = currentAccountAddress
                }
            }

            Label {
                text: "Header style"
                font.bold: true
                Layout.fillWidth: true
            }
            AccountSelectorHeader {
                id: accountSelector2
                model: walletAccountsSelectorAdaptor.processedWalletAccounts
                onCurrentAccountAddressChanged: {
                    accountSelector.selectedAddress = currentAccountAddress
                }
            }
        }

    }

    Item {
        SplitView.preferredWidth: 300
        SplitView.preferredHeight: childrenRect.height

        ColumnLayout {

            Label { text: "Selected Token" }
            ComboBox {
                id: selectedTokenComboBox
                textRole: "name"
                valueRole: "key"
                model: d.assetsStore.walletTokensStore.tokenGroupsModel
                currentIndex: -1
            }

            Label { text: "Selected Network" }
            ComboBox {
                id: networksComboBox
                textRole: "chainName"
                valueRole: "chainId"
                model: d.filteredFlatNetworksModel
                currentIndex: -1
            }
        }
    }
}

// category: Components
