import QtQuick
import utils
import SortFilterProxyModel

QtObject {
    id: root

    property var ensUsernamesModule

    property var ensUsernamesModel: root.ensUsernamesModule ? ensUsernamesModule.model : []

    readonly property bool areTestNetworksEnabled: networksModule.areTestNetworksEnabled

    readonly property QtObject currentChainEnsUsernamesModel: SortFilterProxyModel {
        sourceModel: root.ensUsernamesModel
        filters: ValueFilter {
            roleName: "chainId"
            value: root.chainId
        }
    }

    property string pubkey: userProfile.pubKey
    property string icon: userProfile.icon
    property string preferredUsername: userProfile.preferredName
    readonly property string chainId: mainModule.appNetworkId

    property string username: userProfile.username

    function setPrefferedEnsUsername(ensName) {
        if(!root.ensUsernamesModule)
            return
        ensUsernamesModule.setPrefferedEnsUsername(ensName)
    }

    function checkEnsUsernameAvailability(ensName, isStatus) {
        if(!root.ensUsernamesModule)
            return
        ensUsernamesModule.checkEnsUsernameAvailability(ensName, isStatus)
    }

    function numOfPendingEnsUsernames() {
        if(!root.ensUsernamesModule)
            return 0
        return ensUsernamesModule.numOfPendingEnsUsernames()
    }

    function ensDetails(chainId, ensUsername) {
        if(!root.ensUsernamesModule)
            return ""
        ensUsernamesModule.fetchDetailsForEnsUsername(chainId, ensUsername)
    }


    function getEtherscanTxLink() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getEtherscanTxLink()
    }

    function getEtherscanAddressLink() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getEtherscanAddressLink()
    }

    function ensConnectOwnedUsername(name, isStatus) {
        if(!root.ensUsernamesModule)
            return
        ensUsernamesModule.connectOwnedUsername(name, isStatus)
    }

    function getEnsRegisteredAddress() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getEnsRegisteredAddress()
    }

    function getEnsRegistry() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getEnsRegistry()
    }

    function getWalletDefaultAddress() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getWalletDefaultAddress()
    }

    function getCurrentCurrency() {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getCurrentCurrency()
    }

    function getStatusTokenKey(chainId) {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.getStatusTokenKeyForChainId(chainId)
    }

    function getStatusTokenGroupKey() {
        if (root.areTestNetworksEnabled)
            return Constants.sttGroupKey
        return Constants.sntGroupKey
    }

    function getChainForBuyingEnsName() {
        if (root.areTestNetworksEnabled)
            return Constants.chains.sepoliaChainId
        return Constants.chains.mainnetChainId
    }

    function removeEnsUsername(chainId, ensUsername) {
        if(!root.ensUsernamesModule)
            return ""
        return ensUsernamesModule.removeEnsUsername(chainId, ensUsername)
    }

    function getEnsnameResolverAddress(ensUsername) {
        return ensUsernamesModule.ensnameResolverAddress(ensUsername)
    }
}

