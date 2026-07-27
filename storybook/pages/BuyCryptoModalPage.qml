import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Backpressure

import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors

import utils

import Storybook
import Models
import Mocks

SplitView {
    id: root

    orientation: Qt.Horizontal

    QtObject {
        id: d
        property string uuid
        property var debounceFetchProviderUrl: Backpressure.debounce(root, 500, function() {
            d.buyCryptoStore.providerUrlReady(d.uuid, "xxxx")
        })
        property var debounceFetchProvidersList: Backpressure.debounce(root, 500, function() {
            d.buyCryptoStore.areProvidersLoading = false
        })
        readonly property var buyCryptoStore: BuyCryptoStore {
            readonly property var providersModel: OnRampProvidersModel{}
            property bool areProvidersLoading
            signal providerUrlReady(string uuid , string url)

            function fetchProviders() {
                console.warn("fetchProviders called >>")
                areProvidersLoading = true
                d.debounceFetchProvidersList()
            }

            function fetchProviderUrl(uuid, providerID,
                                      isRecurrent, accountAddress = "",
                                      chainID = 0, symbol = "") {
                console.warn("fetchProviderUrl called >> uuid: ", uuid, "providerID: ",providerID
                             , "isRecurrent: ", isRecurrent, "accountAddress: ", accountAddress,
                             "chainID: ", chainID, "symbol: ", symbol)
                d.uuid = uuid
                d.debounceFetchProviderUrl()
            }
        }

        readonly property var assetsStore: WalletAssetsStoreMock {
            id: thisWalletAssetStore
            walletTokensStore: TokensStoreMock {
                tokenGroupsModel: TokenGroupsModel {}
            }
            readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
        }
        readonly property BuyCryptoParamsForm buyCryptoInputParamsForm: BuyCryptoParamsForm{
            selectedWalletAddress: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            selectedNetworkChainId: 11155111
            selectedTokenGroupKey: "eth-native"
        }

    }

    PopupBackground {
        id: popupBg

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            id: reopenButton
            anchors.centerIn: parent
            text: "Reopen"
            enabled: !buySellModal.visible

            onClicked: {
                buySellModal.buyCryptoInputParamsForm.selectedWalletAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
                buySellModal.buyCryptoInputParamsForm.selectedNetworkChainId = 11155111
                buySellModal.buyCryptoInputParamsForm.selectedTokenKey = "ETH"
                buySellModal.open()
            }
        }

        BuyCryptoModal {
            id: buySellModal
            anchors.centerIn: parent
            visible: true
            modal: false
            closePolicy: Popup.CloseOnEscape
            buyProvidersModel: d.buyCryptoStore.providersModel
            isBuyProvidersModelLoading: d.buyCryptoStore.areProvidersLoading
            walletAccountsModel: WalletAccountsModel{}
            networksModel: NetworksModel.flatNetworks
            tokenGroupsModel: d.assetsStore.walletTokensStore.tokenGroupsModel
            groupedAccountAssetsModel: d.assetsStore.groupedAccountAssetsModel
            buyCryptoInputParamsForm: d.buyCryptoInputParamsForm
            tokenSelectorModel: TokenSelectorModelMock {
                sourceData: [
                    {
                        key: "ETH", name: "Ether", symbol: "ETH",
                        logoUri: Constants.tokenIcon("ETH"), decimals: 18,
                        currencyBalance: 4276.86, cryptoPrice: 3500.0, sectionName: "Popular assets",
                        balances: [ { chainId: 1, iconUrl: "network/ethereum", chainName: "Mainnet", balance: 1.22, rawBalance: "1220000000000000000" } ],
                        tokens: [ { key: "ETH", chainId: 1 } ]
                    },
                    {
                        key: "DAI", name: "Dai Stablecoin", symbol: "DAI",
                        logoUri: Constants.tokenIcon("DAI"), decimals: 18,
                        currencyBalance: 45.92, cryptoPrice: 1.0, sectionName: "Popular assets",
                        balances: [ { chainId: 1, iconUrl: "network/ethereum", chainName: "Mainnet", balance: 45.0, rawBalance: "45000000000000000000" } ],
                        tokens: [ { key: "DAI", chainId: 1 } ]
                    }
                ]
            }
            Component.onCompleted: {
                fetchProviders.connect(d.buyCryptoStore.fetchProviders)
                fetchProviderUrl.connect(d.buyCryptoStore.fetchProviderUrl)
                d.buyCryptoStore.providerUrlReady.connect(providerUrlReady)
            }
        }
    }
}

// category: Popups
