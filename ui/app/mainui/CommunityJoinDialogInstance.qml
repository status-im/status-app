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
    id: dialogRoot

    required property Popups host

    property CommunityStores.CommunityRootStore communityRootStore: dialogRoot.host.messagingRootStore.createCommunityRootStore(this, dialogRoot.communityId)
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                     communityRootStore.communityAccessStore : null

    requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
    checkingPermissionToJoinInProgress: dialogRoot.host.rootStore.checkingPermissionToJoinInProgress
    joinPermissionsCheckCompletedWithoutErrors: dialogRoot.host.rootStore.joinPermissionsCheckCompletedWithoutErrors

    walletAccountsModel: dialogRoot.host.rootStore.walletAccountsModel
    walletCollectiblesModel: WalletStores.RootStore.collectiblesStore.allCollectiblesModel

    walletAssetsModel: dialogRoot.host.walletAssetsStore.groupedAccountAssetsModel
    permissionsModel: {
        if(communityAccessStore) {
            communityAccessStore.prepareTokenModelForCommunity(dialogRoot.communityId)
            return communityAccessStore.spectatedPermissionsModel
        }
        return null
    }
    assetsModel: dialogRoot.host.rootStore.assetsModel
    collectiblesModel: dialogRoot.host.rootStore.collectiblesModel
    getTokenByKeyOrGroupKeyFromAllTokens: WalletStores.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

    getCurrencyAmount: (balance, key) => {
        return dialogRoot.host.currencyStore.getCurrencyAmount(balance, key)
    }

    onPrepareForSigning: {
        if(communityAccessStore) {
            communityAccessStore.prepareKeypairsForSigning(dialogRoot.communityId, dialogRoot.name, sharedAddresses, airdropAddress, false)
            dialogRoot.keypairSigningModel = dialogRoot.host.rootStore.communitiesModuleInst.keypairsSigningModel
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

    onAboutToShow: { dialogRoot.host.rootStore.communityKeyToImport = dialogRoot.communityId; }

    onClosed: {
        dialogRoot.host.rootStore.communityKeyToImport = "";
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
