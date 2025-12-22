import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.popups
import shared.stores as SharedStores
import shared.stores.send as SendStores

import "views"

import AppLayouts.Communities.views
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Communities.stores as CommunitiesStores

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStore
import AppLayouts.stores as AppLayoutStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores

import StatusQ
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

StackLayout {
    id: root

    // NOTE: This `ChatLayout` is currently a view used for both `Chat` and `Communities` and the API is mixed between both cases.
    // During the transition of refactoring the `ChatStores.RootStore` into `chat specific` or `community specific` stores, this flag
    // will be used on this view to determine specific UI view flows in case of need so that it allows to identify if a certain store
    // value is now separated between `chat` and `community` specific
    required property bool isChatView

    // WIP: It will be refactored step by step (now community permissions and community access logic is not part of this store)
    property ChatStores.RootStore rootStore

    // WIP: This is the new store's structure, now used, `PermissionsStore` and `CommunityAccessStore`. More stores will be added in next steps
    property CommunityStores.CommunityRootStore newCommnityStore
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: newCommnityStore.communityAccessStore
    readonly property CommunityStores.PermissionsStore communityPermissionsStore: newCommnityStore.communityPermissionsStore

    // Rest of stores references (to be reviewed)
    property ChatStores.CreateChatPropertiesStore createChatPropertiesStore
    property CommunitiesStores.CommunitiesStore communitiesStore
    required property WalletStore.TokensStore tokensStore
    required property SendStores.TransactionStore transactionStore
    required property WalletStore.WalletAssetsStore walletAssetsStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore
    required property ProfileStores.AdvancedStore advancedStore
    property bool paymentRequestFeatureEnabled

    property var mutualContactsModel
    property var sectionItemModel

    readonly property bool isOwner: sectionItemModel.memberRole === Constants.memberRole.owner
    readonly property bool isAdmin: sectionItemModel.memberRole === Constants.memberRole.admin
    readonly property bool isTokenMasterOwner: sectionItemModel.memberRole === Constants.memberRole.tokenMaster
    readonly property bool isControlNode: sectionItemModel.isControlNode
    readonly property bool isPrivilegedUser: isControlNode || isOwner || isAdmin || isTokenMasterOwner
    readonly property int isInvitationPending: root.rootStore.chatCommunitySectionModule.requestToJoinState !== Constants.RequestToJoinState.None

    property bool communitySettingsDisabled
    property bool showUsersList

    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText

    property var emojiPopup
    property var stickersPopup

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    // Users related data:
    readonly property bool amIChatAdmin: root.rootStore.amIChatAdmin()
    property var usersModel

    // Navigation:
    // Internal trigger for navigating to messaging details
    property bool navToMsgDetails: false

    // Users related signals
    signal groupMembersUpdateRequested(string membersPubKeysList)

    signal profileButtonClicked()
    signal openAppSearch()
    signal buyStickerPackRequested(string packId, int price)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)

    // Community transfer ownership related props/signals:
    property bool isPendingOwnershipRequest: sectionItemModel.isPendingOwnershipRequest

    // Contacts related data:
    property string myPublicKey

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)
    onIsPrivilegedUserChanged: if (root.currentIndex === 1) root.currentIndex = 0

    // Navigation
    signal showUsersListRequested(bool show)
    signal navToMsgDetailsRequested(bool navigate)

    onCurrentIndexChanged: {
        Global.closeCreateChatView()
    }

    Loader {
        id: mainViewLoader
        readonly property var sectionItem: root.rootStore.chatCommunitySectionModule
        readonly property int accessType: sectionItem.requiresTokenPermissionToJoin ? Constants.communityChatOnRequestAccess
                                                                                    : Constants.communityChatPublicAccess

        sourceComponent: {
            if (sectionItem.isCommunity() && !sectionItem.amIMember) {
                if (sectionItemModel.amIBanned) {
                    return communityBanComponent
                } else if (sectionItem.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin) {
                    return controlNodeOfflineComponent
                } else if (sectionItem.requiresTokenPermissionToJoin) {
                    return joinCommunityViewComponent
                }
            }
            return chatViewComponent
        }
    }

    Connections {
        target: root.communityAccessStore
        function onCommunityMembershipNotificationReceived() {
            root.currentIndex = 1 // go to settings
            if (communitySettingsLoader.item) {
                communitySettingsLoader.item.goTo(Constants.CommunitySettingsSections.Members, Constants.CommunityMembershipSubSections.MembershipRequests)
            }
        }
    }

    Component {
        id: joinCommunityViewComponent
        JoinCommunityView {
            id: joinCommunityView
            readonly property string communityId: sectionItemModel.id
            name: sectionItemModel.name
            introMessage: sectionItemModel.introMessage
            communityDesc: sectionItemModel.description
            color: sectionItemModel.color
            image: sectionItemModel.image
            membersCount: sectionItemModel.joinedMembersCount
            accessType: mainViewLoader.accessType
            joinCommunity: true
            amISectionAdmin: sectionItemModel.memberRole === Constants.memberRole.owner ||
                             sectionItemModel.memberRole === Constants.memberRole.admin ||
                             sectionItemModel.memberRole === Constants.memberRole.tokenMaster
            communityItemsModel: root.rootStore.communityItemsModel
            requirementsMet: root.communityPermissionsStore.allTokenRequirementsMet
            requirementsCheckPending: root.communityAccessStore.communityPermissionsCheckOngoing
            requiresRequest: !sectionItemModel.amIMember
            communityHoldingsModel: root.communityPermissionsStore.becomeMemberPermissionsModel
            viewOnlyHoldingsModel: root.communityPermissionsStore.viewOnlyPermissionsModel
            viewAndPostHoldingsModel: root.communityPermissionsStore.viewAndPostPermissionsModel
            assetsModel: root.rootStore.assetsModel
            collectiblesModel: root.rootStore.collectiblesModel
            requestToJoinState: root.rootStore.chatCommunitySectionModule.requestToJoinState
            openCreateChat: rootStore.openCreateChat
            onAdHocChatButtonClicked: rootStore.openCloseCreateChatView()
            onRequestToJoinClicked: {
                Global.communityIntroPopupRequested(joinCommunityView.communityId, sectionItemModel.name,
                                                    sectionItemModel.introMessage, sectionItemModel.image,
                                                    root.isInvitationPending)
            }
            onInvitationPendingClicked: {
                Global.communityIntroPopupRequested(joinCommunityView.communityId, sectionItemModel.name, sectionItemModel.introMessage,
                                                    sectionItemModel.image, root.isInvitationPending)
            }
        }
    }

    Component {
        id: chatViewComponent
        ChatView {
            id: chatView

            readonly property var sectionItem: root.rootStore.chatCommunitySectionModule
            readonly property string communityId: root.sectionItemModel.id

            objectName: "chatViewComponent"

            rootStore: root.rootStore
            createChatPropertiesStore: root.createChatPropertiesStore
            communitiesStore: root.communitiesStore
            walletAssetsStore: root.walletAssetsStore
            currencyStore: root.currencyStore

            mutualContactsModel: root.mutualContactsModel

            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            sectionItemModel: root.sectionItemModel
            joinedMembersCount: sectionItemModel.joinedMembersCount
            areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled
            amIChatAdmin: root.rootStore.amIChatAdmin()
            amIMember: sectionItem.amIMember
            amISectionAdmin: root.sectionItemModel.memberRole === Constants.memberRole.owner ||
                             root.sectionItemModel.memberRole === Constants.memberRole.admin ||
                             root.sectionItemModel.memberRole === Constants.memberRole.tokenMaster
            hasViewOnlyPermissions: root.communityPermissionsStore.viewOnlyPermissionsModel.count > 0
            sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
            disabledTooltipText: root.disabledTooltipText
            paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled
            showUsersList: root.showUsersList

            hasUnrestrictedViewOnlyPermission: {
                viewOnlyUnrestrictedPermissionHelper.revision

                const model = root.communityPermissionsStore.viewOnlyPermissionsModel
                const count = model.rowCount()

                for (let i = 0; i < count; i++) {
                    const holdings = ModelUtils.get(model, i, "holdingsListModel")

                    if (holdings.rowCount() === 0)
                        return true
                }

                return false
            }

            Instantiator {
                id: viewOnlyUnrestrictedPermissionHelper

                model: root.communityPermissionsStore.viewOnlyPermissionsModel

                property int revision: 0

                delegate: QObject {
                    ModelChangeTracker {
                        model: model.holdingsListModel

                        onRevisionChanged: viewOnlyUnrestrictedPermissionHelper.revision++
                    }
                }
            }

            ModelChangeTracker {
                model: root.communityPermissionsStore.viewOnlyPermissionsModel
                onRevisionChanged: viewOnlyUnrestrictedPermissionHelper.revision++
            }

            hasViewAndPostPermissions: root.communityPermissionsStore.viewAndPostPermissionsModel.count > 0
            viewOnlyPermissionsModel: root.communityPermissionsStore.viewOnlyPermissionsModel
            viewAndPostPermissionsModel: root.communityPermissionsStore.viewAndPostPermissionsModel
            assetsModel: root.rootStore.assetsModel
            collectiblesModel: root.rootStore.collectiblesModel
            requestToJoinState: sectionItem.requestToJoinState
            ensCommunityPermissionsEnabled: root.advancedStore.ensCommunityPermissionsEnabled

            // Community access related data:
            isPendingOwnershipRequest: root.isPendingOwnershipRequest
            allChannelsAreHiddenBecauseNotPermitted: root.communityAccessStore.allChannelsAreHiddenBecauseNotPermitted
            communityMemberReevaluationStatus: root.communityAccessStore.communityMemberReevaluationStatus
            spectatedPermissionsModel: root.communityAccessStore.spectatedPermissionsModel
            chatPermissionsCheckOngoing: root.communityAccessStore.chatPermissionsCheckOngoing
            joined: root.isChatView ? root.rootStore.joined : root.communityAccessStore.joined

            // Unfurling related data:
            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

            // Users related data:
            usersModel: root.usersModel

            // Contacts related data:
            myPublicKey: root.myPublicKey

            // Navigation:
            navToMsgDetails: root.navToMsgDetails

            onGroupMembersUpdateRequested: root.groupMembersUpdateRequested(membersPubKeysList)

            onFinaliseOwnershipClicked: Global.openFinaliseOwnershipPopup(communityId)
            onCommunityInfoButtonClicked: root.currentIndex = 1
            onCommunityManageButtonClicked: root.currentIndex = 1

            onProfileButtonClicked: {
                root.profileButtonClicked()
            }
            onOpenAppSearch: {
                root.openAppSearch()
            }
            onRequestToJoinClicked: {
                Global.communityIntroPopupRequested(communityId, root.sectionItemModel.name, root.sectionItemModel.introMessage,
                                                    root.sectionItemModel.image, root.isInvitationPending)
            }
            onInvitationPendingClicked: {
                Global.communityIntroPopupRequested(communityId, root.sectionItemModel.name, root.sectionItemModel.introMessage,
                                                    root.sectionItemModel.image, root.isInvitationPending)
            }

            onBuyStickerPackRequested: root.buyStickerPackRequested(packId, price)
            onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)

            // Unfurling related requests:
            onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

            onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

            // Contacts related requests:
            onChangeContactNicknameRequest: (pubKey, nickname, displayName, isEdit ) => {
                root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
            }
            onRemoveTrustStatusRequest: (pubKey) => {
                root.removeTrustStatusRequest(pubKey)
            }
            onDismissContactRequest: (chatId, contactRequestId) => {
                root.dismissContactRequest(chatId, contactRequestId)
            }
            onAcceptContactRequest: (chatId, contactRequestId) => {
                root.acceptContactRequest(chatId, contactRequestId)
            }

            // Permissions Related requests:
            onCreatePermissionRequested: (holdings, permissionType, isPrivate, channels) => {
                root.communityPermissionsStore.createPermission(holdings, permissionType, isPrivate, channels)
            }
            onRemovePermissionRequested: (key) => {
                root.communityPermissionsStore.removePermission(key)
            }
            onEditPermissionRequested: (key, holdings, permissionType, channels, isPrivate) => {
                root.communityPermissionsStore.editPermission(key, holdings, permissionType, channels, isPrivate)
            }
            onPrepareTokenModelForCommunityChat: (communityId, chatId) => {
                root.communityAccessStore.prepareTokenModelForCommunityChat(communityId, chatId)
            }

            // Community access related requests:
            onSpectateCommunityRequested: (communityId) => {
                root.communityAccessStore.spectateCommunity(communityId)
            }

            onShowUsersListRequested: show => root.showUsersListRequested(show)

            onNavToMsgDetailsRequested: navigate => root.navToMsgDetailsRequested(navigate)
        }
    }

    Loader {
        id: communitySettingsLoader
        active: root.rootStore.chatCommunitySectionModule.isCommunity() &&
                root.isPrivilegedUser &&
                (root.currentIndex === 1 || !!communitySettingsLoader.item) // lazy load and preserve state after loading
        asynchronous: false // It's false on purpose. We want to load the component synchronously

        sourceComponent: CommunitySettingsView {
            id: communitySettingsView

            rootStore: root.rootStore
            walletAccountsModel: WalletStore.RootStore.nonWatchAccounts
            enabledChainIds: root.networksStore.networkFilters
            onEnableNetwork: root.networksStore.enableNetwork(chainId)
            activeNetworks: root.networksStore.activeNetworks
            tokensStore: root.tokensStore
            transactionStore: root.transactionStore
            advancedStore: root.advancedStore

            isPendingOwnershipRequest: root.isPendingOwnershipRequest
            ensCommunityPermissionsEnabled: root.advancedStore.ensCommunityPermissionsEnabled

            chatCommunitySectionModule: root.rootStore.chatCommunitySectionModule
            community: root.sectionItemModel
            communitySettingsDisabled: root.communitySettingsDisabled
            permissionsModel: root.communityPermissionsStore.permissionsModel

            onLoadMembersRequested: rootStore.loadMembersForSectionId(root.sectionItemModel.id)

            onCommunitySettingsDisabledChanged: if (communitySettingsDisabled) goTo(Constants.CommunitySettingsSections.Overview)

            onBackToCommunityClicked: root.currentIndex = 0
            onFinaliseOwnershipClicked: Global.openFinaliseOwnershipPopup(community.id)

            // Permissions Related requests:
            onCreatePermissionRequested: (holdings, permissionType, isPrivate, channels) => {
                root.communityPermissionsStore.createPermission(holdings, permissionType, isPrivate, channels)
            }
            onRemovePermissionRequested: (key) => {
                root.communityPermissionsStore.removePermission(key)
            }
            onEditPermissionRequested: (key, holdings, permissionType, channels, isPrivate) => {
                root.communityPermissionsStore.editPermission(key, holdings, permissionType, channels, isPrivate)
            }

            // Communtiy access related requests:
            onAcceptRequestToJoinCommunityRequested: (requestId, communityId) => {
                root.communityAccessStore.acceptRequestToJoinCommunityRequested(requestId, communityId)
            }
            onDeclineRequestToJoinCommunityRequested: (requestId, communityId) => {
                root.communityAccessStore.declineRequestToJoinCommunityRequested(requestId, communityId)
            }
        }
    }

    Component {
        id: controlNodeOfflineComponent
        ControlNodeOfflineCommunityView {
            id: controlNodeOfflineView
            name: root.sectionItemModel.name
            communityDesc: root.sectionItemModel.description
            color: root.sectionItemModel.color
            image: root.sectionItemModel.image
            membersCount: sectionItemModel.joinedMembersCount
            communityItemsModel: root.rootStore.communityItemsModel
            onAdHocChatButtonClicked: rootStore.openCloseCreateChatView()
        }
    }

    Component {
        id: communityBanComponent
        BannedMemberCommunityView {
            id: communityBanView
            readonly property var communityData: sectionItemModel
            name: root.sectionItemModel.name
            communityDesc: root.sectionItemModel.description
            color: root.sectionItemModel.color
            image: root.sectionItemModel.image
            membersCount: sectionItemModel.joinedMembersCount
            communityItemsModel: root.rootStore.communityItemsModel
            onAdHocChatButtonClicked: rootStore.openCloseCreateChatView()
        }
    }
}
