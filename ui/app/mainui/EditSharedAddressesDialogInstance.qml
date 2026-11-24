import QtQuick

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores as AppLayoutStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import shared.popups
import shared.stores

CommunityMembershipSetupDialog {
    id: editSharedAddressesPopup

    required property AppLayoutStores.ContactsStore contactsStore
    required property MessagingStores.MessagingRootStore messagingRootStore
    required property AppLayoutStores.RootStore rootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property CurrenciesStore currencyStore

    // TODO: This will be replaced at some point to some combination of `CommunityStores` objects
    readonly property ChatStores.RootStore chatStore: ChatStores.RootStore {
        contactsStore: editSharedAddressesPopup.contactsStore
        isChatSectionModule: false
        communityId: editSharedAddressesPopup.communityId
    }

    property CommunityStores.CommunityRootStore communityRootStore:  editSharedAddressesPopup.messagingRootStore.createCommunityRootStore(this, editSharedAddressesPopup.communityId)
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                     communityRootStore.communityAccessStore : null

    isEditMode: true

    currentSharedAddresses: editSharedAddressesPopup.rootStore.myRevealedAddressesForCurrentCommunity
    currentAirdropAddress: editSharedAddressesPopup.rootStore.myRevealedAirdropAddressForCurrentCommunity

    communityName: chatStore.sectionDetails.name
    communityIcon: chatStore.sectionDetails.image

    requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
    checkingPermissionToJoinInProgress: editSharedAddressesPopup.rootStore.checkingPermissionToJoinInProgress
    joinPermissionsCheckCompletedWithoutErrors: editSharedAddressesPopup.rootStore.joinPermissionsCheckCompletedWithoutErrors

    introMessage: chatStore.sectionDetails.introMessage

    walletAccountsModel: editSharedAddressesPopup.rootStore.walletAccountsModel

    walletAssetsModel: editSharedAddressesPopup.walletAssetsStore.groupedAccountAssetsModel
    walletCollectiblesModel: WalletStores.RootStore.collectiblesStore.allCollectiblesModel

    permissionsModel: {
        if(communityAccessStore) {
            communityAccessStore.prepareTokenModelForCommunity(editSharedAddressesPopup.communityId)
            return communityAccessStore.spectatedPermissionsModel
        }
        return null
    }
    assetsModel: chatStore.assetsModel
    collectiblesModel: chatStore.collectiblesModel
    getTokenByKeyOrGroupKeyFromAllTokens: WalletStores.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

    getCurrencyAmount: (balance, key) => {
        return editSharedAddressesPopup.currencyStore.getCurrencyAmount(balance, key)
    }

    onSharedAddressesUpdated: {
        if(communityAccessStore) {
            communityAccessStore.updatePermissionsModel(editSharedAddressesPopup.communityId, sharedAddresses)
        }
    }

    onPrepareForSigning: {
        if(communityAccessStore) {
            communityAccessStore.prepareKeypairsForSigning(editSharedAddressesPopup.communityId, "", sharedAddresses, airdropAddress, true)
            editSharedAddressesPopup.keypairSigningModel = editSharedAddressesPopup.rootStore.communitiesModuleInst.keypairsSigningModel
        }
    }

    onSignSharedAddressesForKeypair: {
        if(communityAccessStore) {
            communityAccessStore.signSharedAddressesForKeypair(keyUid)
        }
    }

    onEditRevealedAddresses: {
        communityAccessStore.joinCommunityOrEditSharedAddresses()
    }

    onClosed: {
        communityAccessStore.cleanJoinEditCommunityData()
    }

    Connections {
        target: editSharedAddressesPopup.communityAccessStore

        function onAllSharedAddressesSigned() {
            if (!!editSharedAddressesPopup.replaceItem) {
                editSharedAddressesPopup.replaceLoader.item.allSigned()
            }
        }
    }
}
