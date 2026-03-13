import QtQuick

import SortFilterProxyModel

import shared.stores

import utils

import StatusQ
import StatusQ.Core.Utils

import AppLayouts.Wallet.stores

QtObject {
    id: root

    property CurrenciesStore currencyStore
    property WalletAssetsStore walletAssetStore
    property TokensStore tokensStore
    required property NetworksStore networksStore

    property var mainModuleInst: mainModule
    property var walletSectionSendInst: walletSectionSend

    readonly property var accounts: walletSectionAccounts.accounts

    readonly property var fromNetworksRouteModel: walletSectionSendInst.fromNetworksRouteModel
    readonly property var toNetworksRouteModel: walletSectionSendInst.toNetworksRouteModel
    readonly property string selectedReceiverAccountAddress: walletSectionSendInst.selectedReceiveAccountAddress
    readonly property string selectedSenderAccountAddress: walletSectionSendInst.selectedSenderAccountAddress
    property bool areTestNetworksEnabled: networksModule.areTestNetworksEnabled
    property var tmpActivityController0: walletSection.tmpActivityController0
    readonly property var _tmpActivityController1: walletSection.tmpActivityController1
    readonly property var tempActivityController1Model: _tmpActivityController1.model
    property var savedAddressesModel: SortFilterProxyModel {
        sourceModel: walletSectionSavedAddresses.model
        filters: [
            ValueFilter {
                roleName: "isTest"
                value: areTestNetworksEnabled
            }
        ]
    }
    property string selectedAssetKey: walletSectionSendInst.selectedAssetKey
    property bool showUnPreferredChains: walletSectionSendInst.showUnPreferredChains
    property int sendType: walletSectionSendInst.sendType
    property string selectedRecipient: walletSectionSendInst.selectedRecipient

    function setSendType(sendType) {
        walletSectionSendInst.setSendType(sendType)
    }

    function setSelectedRecipient(recipientAddress) {
        walletSectionSendInst.setSelectedRecipient(recipientAddress)
    }

    function getEtherscanTxLink(chainID) {
        return networksModule.getBlockExplorerTxURL(chainID)
    }

    function authenticateAndTransfer(uuid) {
        walletSectionSendInst.authenticateAndTransfer(uuid)
    }

    function suggestedRoutes(uuid, amountIn, amountOut = "0", slippagePercentage = "", extraParamsJson = "") {
        const valueIn = AmountsArithmetic.fromNumber(amountIn)
        const valueOut = AmountsArithmetic.fromNumber(amountOut)
        walletSectionSendInst.suggestedRoutes(uuid, valueIn.toFixed(), valueOut.toFixed(), slippagePercentage, extraParamsJson)
    }

    function resetData() {
        walletSectionSendInst.resetData()
    }

    function resolveENS(value) {
        mainModuleInst.resolveENS(value, "")
    }

    function getWei2Eth(wei, decimals) {
        return globalUtils.wei2Eth(wei, decimals)
    }

    function getAsset(assetsList, symbol) {
        for(var i=0; i< assetsList.rowCount();i++) {
            let asset = assetsList.get(i)
            if(symbol === asset.symbol) {
                return asset
            }
        }
        return {}
    }

    function setSenderAccount(address) {
        walletSectionSendInst.setSenderAccount(address)
    }

    function setReceiverAccount(address) {
        walletSectionSendInst.setReceiverAccount(address)
    }

    function setSelectedTokenName(tokenName) {
        walletSectionSendInst.setSelectedTokenName(tokenName)
    }

    function setSelectedTokenIsOwnerToken(isOwnerToken) {
        walletSectionSendInst.setSelectedTokenIsOwnerToken(isOwnerToken)
    }

    function setRouteEnabledChainFrom(chainId) {
        walletSectionSendInst.fromNetworksRouteModel.setRouteEnabledChain(chainId)
    }

    function setRouteEnabledChainTo(chainId) {
        walletSectionSendInst.toNetworksRouteModel.setRouteEnabledChain(chainId)
    }

    function setSelectedAssetKey(assetsKey) {
        walletSectionSendInst.setSelectedAssetKey(assetsKey)
    }

    function getNetworkName(chainId) {
        return ModelUtils.getByKey(root.networksStore.allNetworks, "chainId", chainId, "chainName")
    }

    function updateRoutePreferredChains(chainIds) {
        walletSectionSendInst.updateRoutePreferredChains(chainIds)
    }

    function toggleShowUnPreferredChains() {
        walletSectionSendInst.toggleShowUnPreferredChains()
    }

    function lockCard(chainId, amount, lock) {
        walletSectionSendInst.fromNetworksRouteModel.lockCard(chainId, amount, lock)
    }

    function splitAndFormatAddressPrefix(text, updateInStore) {
        return {
            formattedText: walletSectionSendInst.splitAndFormatAddressPrefix(text, updateInStore),
            address: walletSectionSendInst.getAddressFromFormattedString(text)
        }
    }

    function formatCurrencyAmountFromBigInt(balance, symbol, decimals, options = null) {
        return currencyStore.formatCurrencyAmountFromBigInt(balance, symbol, decimals, options)
    }

    function updateRecentRecipientsActivity(accountAddress) {
        if(!!accountAddress) {
            _tmpActivityController1.setFilterAddressesJson(JSON.stringify([accountAddress]),
                                                                      false)
        }
        _tmpActivityController1.updateFilter()
    }
}
