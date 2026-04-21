import QtQuick
import QtQuick.Layouts
import QtQml.Models
import SortFilterProxyModel

import StatusQ
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.stores

import QtModelsToolkit

StatusStackModal {
    id: root

    // required data
    required property var buyProvidersModel
    required property var isBuyProvidersModelLoading

    required property BuyCryptoParamsForm buyCryptoInputParamsForm
    required property var tokenGroupsModel
    required property var groupedAccountAssetsModel
    required property var walletAccountsModel
    required property var networksModel
    required property string currentCurrency

    signal fetchProviders()
    signal fetchProviderUrl(string uuid,
                            string providerID,
                            bool isRecurrent,
                            string selectedWalletAddress,
                            int chainID,
                            string symbol)

    // FIXME handling error in case the response is not successful
    function providerUrlReady(uuid, url) {
        if(uuid === d.uuid) {
            d.urlIsBeingFetched = false
            if (!!d.selectedProviderEntry.item && !!url)
                Global.requestOpenLink(url)
            root.close()
        }
    }
    
    QtObject {
        id: d

        // States to track requests
        property string uuid
        property bool urlIsBeingFetched

        readonly property var buyButton: StatusButton {
            height: root.finishButton.height
            visible: !!root.replaceItem
            borderColor: "transparent"
            text: qsTr("Buy via %1").arg(!!d.selectedProviderEntry.item ? d.selectedProviderEntry.item.name: "")
            loading: d.urlIsBeingFetched
            onClicked: {
                if(!!d.selectedProviderEntry.item && !!d.selectedTokenEntry.item) {
                    d.fetchProviderUrl(
                                root.buyCryptoInputParamsForm.selectedProviderId,
                                buyCryptoProvidersListPanel.currentTabIndex,
                                root.buyCryptoInputParamsForm.selectedWalletAddress,
                                root.buyCryptoInputParamsForm.selectedNetworkChainId,
                                d.selectedTokenEntry.item.symbol
                                )
                }
            }
            enabled: root.buyCryptoInputParamsForm.filledCorrectly
        }

        readonly property ModelEntry selectedAccountEntry: ModelEntry {
            sourceModel: root.walletAccountsModel
            key: "address"
            value: root.buyCryptoInputParamsForm.selectedWalletAddress
        }

        readonly property ModelEntry selectedTokenEntry: ModelEntry {
            sourceModel: root.tokenGroupsModel
            key: "key"
            value: root.buyCryptoInputParamsForm.selectedTokenGroupKey
        }

        readonly property ModelEntry selectedProviderEntry: ModelEntry {
            id: selectedProviderEntry
            sourceModel: root.buyProvidersModel
            key: "id"
            value: root.buyCryptoInputParamsForm.selectedProviderId
        }

        function fetchProviderUrl(
            providerID,
            isRecurrent,
            accountAddress = "",
            chainID = 0,
            symbol = "") {
            // Identify new search with a different uuid
            d.uuid = Utils.uuid()
            d.urlIsBeingFetched = true
            root.fetchProviderUrl(d.uuid, providerID, isRecurrent,
                                            accountAddress, chainID, symbol)
        }

        // used to filter items based on search string in the token selector

        readonly property var tokenSelectorViewAdaptor: TokenSelectorViewAdaptor {
            assetsModel: root.groupedAccountAssetsModel
            allTokenGroupsForChainModel: root.tokenGroupsModel
            flatNetworksModel: root.networksModel
            currentCurrency: root.currentCurrency

            showAllTokens: true
            enabledChainIds: root.buyCryptoInputParamsForm.selectedNetworkChainId !== -1 ? [root.buyCryptoInputParamsForm.selectedNetworkChainId] : []
            accountAddress: root.buyCryptoInputParamsForm.selectedWalletAddress
        }

        readonly property var buyCryptoAdaptor: BuyCryptoModalAdaptor {
            networksModel: root.networksModel
            processedTokenSelectorAssetsModel: d.tokenSelectorViewAdaptor.outputAssetsModel
            selectedProviderSupportedAssetsArray: {
                if (!!d.selectedProviderEntry.item && !!d.selectedProviderEntry.item.supportedAssets)
                    return ModelUtils.modelToFlatArray(d.selectedProviderEntry.item.supportedAssets, "key")
                return null
            }
            selectedChainId: root.buyCryptoInputParamsForm.selectedNetworkChainId
        }
    }

    width: 560
    padding: Theme.xlPadding
    stackTitle: !!root.buyCryptoInputParamsForm.selectedTokenGroupKey ?
                    qsTr("Ways to buy %1 for %2").arg(d.selectedTokenEntry.item.name).arg(!!d.selectedAccountEntry.item ? d.selectedAccountEntry.item.name: "")
                  : qsTr("Ways to buy assets for %1").arg(!!d.selectedAccountEntry.item ? d.selectedAccountEntry.item.name: "")
    rightButtons: [d.buyButton, finishButton]
    finishButton: StatusButton {
        text: qsTr("Done")
        onClicked: root.close()
    }

    onOpened: root.fetchProviders()
    onClosed: {
        // reset the view
        d.uuid = ""
        d.urlIsBeingFetched = false
        root.replaceItem = undefined
        buyCryptoProvidersListPanel.currentTabIndex = 0
        root.buyCryptoInputParamsForm.resetFormData()
    }

    stackItems: [
        BuyCryptoProvidersListPanel {
            id: buyCryptoProvidersListPanel
            providersLoading: root.isBuyProvidersModelLoading
            providersModel: root.buyProvidersModel
            selectedProviderId: root.buyCryptoInputParamsForm.selectedProviderId
            isUrlBeingFetched: d.urlIsBeingFetched
            onProviderSelected: {
                root.buyCryptoInputParamsForm.selectedProviderId = id
                if(!!d.selectedProviderEntry.item) {
                    if(d.selectedProviderEntry.item.urlsNeedParameters) {
                        root.replace(selectParamsPanel)
                    } else {
                        d.fetchProviderUrl(d.selectedProviderEntry.item.id, currentTabIndex)
                    }
                }
            }
        }
    ]

    Component {
        id: selectParamsPanel
        SelectParamsForBuyCryptoPanel {
            objectName: "selectParamsPanel"
            assetsModel: d.buyCryptoAdaptor.filteredAssetsModel
            selectedProvider: d.selectedProviderEntry.item
            selectedTokenGroupKey: root.buyCryptoInputParamsForm.selectedTokenGroupKey
            selectedNetworkChainId: root.buyCryptoInputParamsForm.selectedNetworkChainId
            filteredFlatNetworksModel: d.buyCryptoAdaptor.networksModel
            onNetworkSelected: (chainId) => {
                if (root.buyCryptoInputParamsForm.selectedNetworkChainId !== chainId) {
                    root.buyCryptoInputParamsForm.selectedNetworkChainId = chainId
                }
            }
            onTokenSelected: (tokenGroupKey) => {
                if (root.buyCryptoInputParamsForm.selectedTokenGroupKey !== tokenGroupKey) {
                    root.buyCryptoInputParamsForm.selectedTokenGroupKey = tokenGroupKey
                }
            }
        }
    }
}
