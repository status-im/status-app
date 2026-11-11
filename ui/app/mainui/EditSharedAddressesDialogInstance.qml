import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml
import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.popups
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.services.dapps
import mainui.popups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import shared.popups
import shared.popups.authentication
import shared.popups.authentication.stores 1.0 as AuthStores
import shared.popups.signing
import shared.popups.signing.stores 1.0 as SignStores
import shared.popups.keycard_new
import shared.popups.keycard_new.stores 1.0 as KeycardMgmtStores
import shared.status
import shared.stores
import shared.views
import shared.views.profile
import utils

CommunityMembershipSetupDialog {
    id: editSharedAddressesPopup

    required property Popups host

    // TODO: This will be replaced at some point to some combination of `CommunityStores` objects
    readonly property ChatStores.RootStore chatStore: ChatStores.RootStore {
        contactsStore: editSharedAddressesPopup.host.contactsStore
        isChatSectionModule: false
        communityId: editSharedAddressesPopup.communityId
    }

    property CommunityStores.CommunityRootStore communityRootStore:  editSharedAddressesPopup.host.messagingRootStore.createCommunityRootStore(this, editSharedAddressesPopup.communityId)
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                     communityRootStore.communityAccessStore : null

    isEditMode: true

    currentSharedAddresses: editSharedAddressesPopup.host.rootStore.myRevealedAddressesForCurrentCommunity
    currentAirdropAddress: editSharedAddressesPopup.host.rootStore.myRevealedAirdropAddressForCurrentCommunity

    communityName: chatStore.sectionDetails.name
    communityIcon: chatStore.sectionDetails.image

    requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
    checkingPermissionToJoinInProgress: editSharedAddressesPopup.host.rootStore.checkingPermissionToJoinInProgress
    joinPermissionsCheckCompletedWithoutErrors: editSharedAddressesPopup.host.rootStore.joinPermissionsCheckCompletedWithoutErrors

    introMessage: chatStore.sectionDetails.introMessage

    walletAccountsModel: editSharedAddressesPopup.host.rootStore.walletAccountsModel

    walletAssetsModel: editSharedAddressesPopup.host.walletAssetsStore.groupedAccountAssetsModel
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
        return editSharedAddressesPopup.host.currencyStore.getCurrencyAmount(balance, key)
    }

    onSharedAddressesUpdated: {
        if(communityAccessStore) {
            communityAccessStore.updatePermissionsModel(editSharedAddressesPopup.communityId, sharedAddresses)
        }
    }

    onPrepareForSigning: {
        if(communityAccessStore) {
            communityAccessStore.prepareKeypairsForSigning(editSharedAddressesPopup.communityId, "", sharedAddresses, airdropAddress, true)
            editSharedAddressesPopup.keypairSigningModel = editSharedAddressesPopup.host.rootStore.communitiesModuleInst.keypairsSigningModel
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
