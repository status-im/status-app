import QtQuick

import AppLayouts.stores as AppLayoutStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import shared.popups
import shared.stores

CommunityMembershipSetupDialog {
    id: dialogRoot

    required property MessagingStores.MessagingRootStore messagingRootStore
    required property AppLayoutStores.RootStore rootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property CurrenciesStore currencyStore

    property CommunityStores.CommunityRootStore communityRootStore: dialogRoot.messagingRootStore.createCommunityRootStore(this, dialogRoot.communityId)
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                     communityRootStore.communityAccessStore : null

    requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
    checkingPermissionToJoinInProgress: dialogRoot.rootStore.checkingPermissionToJoinInProgress
    joinPermissionsCheckCompletedWithoutErrors: dialogRoot.rootStore.joinPermissionsCheckCompletedWithoutErrors

    walletAccountsModel: dialogRoot.rootStore.walletAccountsModel
    walletCollectiblesModel: WalletStores.RootStore.collectiblesStore.allCollectiblesModel

    walletAssetsModel: dialogRoot.walletAssetsStore.groupedAccountAssetsModel
    permissionsModel: {
        if(communityAccessStore) {
            communityAccessStore.prepareTokenModelForCommunity(dialogRoot.communityId)
            return communityAccessStore.spectatedPermissionsModel
        }
        return null
    }
    assetsModel: dialogRoot.rootStore.assetsModel
    collectiblesModel: dialogRoot.rootStore.collectiblesModel
    getTokenByKeyOrGroupKeyFromAllTokens: WalletStores.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

    getCurrencyAmount: (balance, key) => {
        return dialogRoot.currencyStore.getCurrencyAmount(balance, key)
    }

    onPrepareForSigning: {
        if(communityAccessStore) {
            communityAccessStore.prepareKeypairsForSigning(dialogRoot.communityId, dialogRoot.name, sharedAddresses, airdropAddress, false)
            dialogRoot.keypairSigningModel = dialogRoot.rootStore.communitiesModuleInst.keypairsSigningModel
        }
    }

    onSignSharedAddressesForKeypair: {
        if(communityAccessStore) {
            communityAccessStore.signSharedAddressesForKeypair(keyUid)
        }
    }

    onJoinCommunity: {
        if(communityAccessStore) {
            communityAccessStore.joinCommunityOrEditSharedAddresses()
        }
    }

    onCancelMembershipRequest: {
        if(communityAccessStore) {
            communityAccessStore.cancelPendingRequest(dialogRoot.communityId)
        }
    }

    onSharedAddressesUpdated: {
        if(communityAccessStore) {
            communityAccessStore.updatePermissionsModel(dialogRoot.communityId, sharedAddresses)
        }
    }

    onAboutToShow: { dialogRoot.rootStore.communityKeyToImport = dialogRoot.communityId; }

    onClosed: {
        dialogRoot.rootStore.communityKeyToImport = "";
        if(communityAccessStore) {
            communityAccessStore.cleanJoinEditCommunityData()
        }
    }

    Connections {
        target: dialogRoot.communityAccessStore

        function onCommunityAccessFailed(communityId: string, error: string) {
            if (communityId !== dialogRoot.communityId)
                return
            dialogRoot.close();
        }

        function onAllSharedAddressesSigned() {
            if (!!dialogRoot.replaceItem) {
                dialogRoot.replaceLoader.item.allSigned()
            }
        }
    }
}
