import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared
import shared.panels
import shared.popups
import shared.status
import shared.stores as SharedStores
import shared.views.chat
import shared.stores.send as SendStores
import SortFilterProxyModel

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Layout
import StatusQ.Popups

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Communities.views

import AppLayouts.Profile.stores
import AppLayouts.Wallet.stores as WalletStore

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores as AppLayoutStores

import "../controls"
import "../helpers"
import "../panels"
import "../popups"

StatusSectionLayout {
    id: root

    property ChatStores.RootStore rootStore
    property ChatStores.CreateChatPropertiesStore createChatPropertiesStore
    property CommunitiesStores.CommunitiesStore communitiesStore
    required property WalletStore.WalletAssetsStore walletAssetsStore
    required property SharedStores.CurrenciesStore currencyStore

    property var mutualContactsModel

    property var sectionItemModel
    property int joinedMembersCount
    property bool areTestNetworksEnabled

    property var emojiPopup
    property var stickersPopup
    property bool stickersLoaded: false

    readonly property var chatContentModule: rootStore.currentChatContentModule() || null
    readonly property bool canView: chatContentModule.chatDetails.canView
    readonly property bool canPost: chatContentModule.chatDetails.canPost
    readonly property bool missingEncryptionKey: chatContentModule.chatDetails.missingEncryptionKey

    property bool hasViewOnlyPermissions: false
    property bool hasUnrestrictedViewOnlyPermission: false

    property bool hasViewAndPostPermissions: false
    property bool amIMember: false
    property bool amISectionAdmin: false
    property bool allChannelsAreHiddenBecauseNotPermitted: false
    property bool showUsersList: false

    property int requestToJoinState: Constants.RequestToJoinState.None

    // Settings related:
    property bool ensCommunityPermissionsEnabled

    property var viewOnlyPermissionsModel
    property var viewAndPostPermissionsModel
    property var assetsModel
    property var collectiblesModel

    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText
    property bool paymentRequestFeatureEnabled

    readonly property bool contentLocked: {
        if (!rootStore.chatCommunitySectionModule.isCommunity()) {
            return false
        }
        if (!amIMember) {
            if (hasUnrestrictedViewOnlyPermission)
                return false

            return hasViewAndPostPermissions || hasViewOnlyPermissions
        }
        if (amISectionAdmin) {
            return false
        }
        if (!hasViewAndPostPermissions && hasViewOnlyPermissions) {
            return !canView
        }
        if (hasViewAndPostPermissions && !hasViewOnlyPermissions) {
            return !canPost
        }
        if (hasViewOnlyPermissions && hasViewAndPostPermissions) {
            return !canView && !canPost
        }
        return false
    }

    // Community access related data:
    property int communityMemberReevaluationStatus
    property var spectatedPermissionsModel
    property bool chatPermissionsCheckOngoing
    property bool joined

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    // Users related data:
    property var usersModel
    property bool amIChatAdmin

    // Navigation:
    // Internal trigger for navigating to messaging details
    property bool navToMsgDetails: false

    // Users related signals
    signal groupMembersUpdateRequested(string membersPubKeysList)

    // Contacts related data:
    property string myPublicKey

    // Community transfer ownership related props:
    required property bool isPendingOwnershipRequest
    signal finaliseOwnershipClicked

    signal communityInfoButtonClicked()
    signal communityManageButtonClicked()
    signal profileButtonClicked()
    signal openAppSearch()

    signal requestToJoinClicked
    signal invitationPendingClicked

    signal buyStickerPackRequested(string packId, int price)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)

    // Permissions Related requests:
    signal createPermissionRequested(var holdings, int permissionType, bool isPrivate, var channels)
    signal removePermissionRequested(string key)
    signal editPermissionRequested(string key, var holdings, int permissionType, var channels, bool isPrivate)
    signal prepareTokenModelForCommunityChat(string communityId, string chatId)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    // Navigation
    signal showUsersListRequested(bool show)
    signal navToMsgDetailsRequested(bool navigate)

    Connections {
        target: root.rootStore.stickersStore.stickersModule

        function onStickerPacksLoaded() {
            root.stickersLoaded = true;
        }
    }

    Connections {
        target: root.rootStore.chatCommunitySectionModule
        ignoreUnknownSignals: true

        function onActiveItemChanged() {
            Global.closeCreateChatView()
        }
    }

    headerContent: Loader {
        visible: !root.allChannelsAreHiddenBecauseNotPermitted
        id: headerContentLoader
        sourceComponent: root.contentLocked ? joinCommunityHeaderPanelComponent : chatHeaderContentViewComponent
    }

    leftPanel: Loader {
        id: contactColumnLoader
        sourceComponent: root.rootStore.chatCommunitySectionModule.isCommunity()?
                             communtiyColumnComponent :
                             contactsColumnComponent
    }

    centerPanel: Loader {
        anchors.fill: parent
        sourceComponent: (root.allChannelsAreHiddenBecauseNotPermitted || root.contentLocked) ?
                             joinCommunityCenterPanelComponent : chatColumnViewComponent
    }

    showRightPanel: {
        if (root.contentLocked || root.rootStore.openCreateChat ||
                !root.showUsersList || !root.chatContentModule)
            return false

        // Check if user list is available as an option for particular chat content module
        return root.chatContentModule.chatDetails.isUsersListAvailable
    }

    rightPanel: UserListPanel {
        anchors.fill: parent

        chatType: root.chatContentModule.chatDetails.type
        isAdmin: root.chatContentModule.amIChatAdmin()

        label: qsTr("Members")
        communityMemberReevaluationStatus: root.communityMemberReevaluationStatus

        usersModel: root.usersModel

        onOpenProfileRequested: Global.openProfilePopup(pubKey, null)
        onReviewContactRequestRequested: Global.openReviewContactRequestPopup(pubKey, null)
        onSendContactRequestRequested: Global.openContactRequestPopup(pubKey, null)
        onEditNicknameRequested: Global.openNicknamePopupRequested(pubKey, null)
        onBlockContactRequested: Global.blockContactRequested(pubKey)
        onUnblockContactRequested: Global.unblockContactRequested(pubKey)
        onMarkAsUntrustedRequested: Global.markAsUntrustedRequested(pubKey)
        onRemoveContactRequested: Global.removeContactRequested(pubKey)

        onRemoveNicknameRequested: {
            const oldName = ModelUtils.getByKey(usersModel, "pubKey", pubKey, "localNickname")
            root.changeContactNicknameRequest(pubKey, "", oldName, true)
        }

        onCreateOneToOneChatRequested: {
            Global.changeAppSectionBySectionType(Constants.appSection.chat)
            root.rootStore.chatCommunitySectionModule.createOneToOneChat("", pubKey, "")
        }

        onRemoveTrustStatusRequested: root.removeTrustStatusRequest(pubKey)
        onRemoveContactFromGroupRequested: root.rootStore.removeMemberFromGroupChat(pubKey)

        onMarkAsTrustedRequested: Global.openMarkAsIDVerifiedPopup(pubKey, null)
        onRemoveTrustedMarkRequested: Global.openRemoveIDVerificationDialog(pubKey, null)
    }

    onChatContentModuleChanged: {
        if (!root.chatContentModule || !root.chatContentModule.chatDetails)
            return

        // WORKAROUND: This forces navigation to community details (specific channel) or
        // specific 1:1 chat whenever the active section is set and comes from a in-app link
        // navigation where the ui-state is stored temporaryly in main root store
        //
        // NOTE: It only affects behavior in portrait mode
        if(root.navToMsgDetails) {
            root.goToNextPanel()
            root.navToMsgDetailsRequested(false)
        }
    }

    Component {
        id: chatHeaderContentViewComponent
        ChatHeaderContentView {
            visible: !!root.rootStore.currentChatContentModule()

            rootStore: root.rootStore
            mutualContactsModel: root.mutualContactsModel
            emojiPopup: root.emojiPopup

            usersModel: root.usersModel
            amIChatAdmin: root.amIChatAdmin
            showMembersButtonHighlighted: root.showUsersList

            onSearchButtonClicked: root.openAppSearch()
            onDisplayEditChannelPopup: {
                Global.openPopup(contactColumnLoader.item.createChannelPopup, {
                    isEdit: true,
                    chatId: chatId,
                    channelName: chatName,
                    channelDescription: chatDescription,
                    channelEmoji: chatEmoji,
                    channelColor: chatColor,
                    categoryId: chatCategoryId,
                    channelPosition: channelPosition,
                    deleteChatConfirmationDialog: deleteDialog,
                    hideIfPermissionsNotMet: hideIfPermissionsNotMet
                });
            }

            onGroupMembersUpdateRequested: root.groupMembersUpdateRequested(membersPubKeysList)
            onToggleShowMembersRequested: root.showUsersListRequested(!root.showUsersList)
        }
    }

    Component {
        id: joinCommunityHeaderPanelComponent
        JoinCommunityHeaderPanel {
            readonly property var chatContentModule: root.rootStore.currentChatContentModule() || null
            joinCommunity: false
            color: chatContentModule.chatDetails.color
            channelName: chatContentModule.chatDetails.name
            channelDesc: chatContentModule.chatDetails.description
        }
    }

    Component {
        id: chatColumnViewComponent

        ChatColumnView {
            parentModule: root.rootStore.chatCommunitySectionModule
            rootStore: root.rootStore
            areTestNetworksEnabled: root.areTestNetworksEnabled
            createChatPropertiesStore: root.createChatPropertiesStore
            stickersLoaded: root.stickersLoaded
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            viewAndPostHoldingsModel: root.viewAndPostPermissionsModel
            canPost: !root.rootStore.chatCommunitySectionModule.isCommunity() || root.canPost
            amISectionAdmin: root.amISectionAdmin
            sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
            disabledTooltipText: root.disabledTooltipText
            paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled
            joined: root.joined

            // Unfurling related data:
            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

            // Users related data:
            usersModel: root.usersModel

            // Contacts related data:
            myPublicKey: root.myPublicKey

            onOpenStickerPackPopup: {
                Global.openPopup(statusStickerPackClickPopup, {packId: stickerPackId, store: root.stickersPopup.store} )
            }
            onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)

            // Unfurling related requests:
            onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

            onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

            // Contacts related requests:
            onChangeContactNicknameRequest: root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
            onRemoveTrustStatusRequest: root.removeTrustStatusRequest(pubKey)
            onDismissContactRequest: root.dismissContactRequest(chatId, contactRequestId)
            onAcceptContactRequest: root.acceptContactRequest(chatId, contactRequestId)

            // Community access related requests:
            onSpectateCommunityRequested: (communityId) => {
                root.spectateCommunityRequested(communityId)
            }
        }
    }

    Component {
        id: joinCommunityCenterPanelComponent

        JoinCommunityCenterPanel {
            joinCommunity: false
            allChannelsAreHiddenBecauseNotPermitted: root.allChannelsAreHiddenBecauseNotPermitted
            name: sectionItemModel.name
            channelName: root.chatContentModule.chatDetails.name
            viewOnlyHoldingsModel: root.viewOnlyPermissionsModel
            viewAndPostHoldingsModel: root.viewAndPostPermissionsModel
            assetsModel: root.assetsModel
            collectiblesModel: root.collectiblesModel
            requestToJoinState: root.requestToJoinState
            requiresRequest: !root.amIMember
            requirementsMet: root.missingEncryptionKey ||
                             (root.canView && viewOnlyPermissionsModel.count > 0) ||
                             (root.canPost && viewAndPostPermissionsModel.count > 0)
            requirementsCheckPending: root.chatPermissionsCheckOngoing
            missingEncryptionKey: root.missingEncryptionKey
            onRequestToJoinClicked: root.requestToJoinClicked()
            onInvitationPendingClicked: root.invitationPendingClicked()
        }
    }

    Component {
        id: contactsColumnComponent
        ContactsColumnView {
            chatSectionModule: root.rootStore.chatCommunitySectionModule
            store: root.rootStore
            emojiPopup: root.emojiPopup

            onShareOwnProfileRequested: Global.shareProfileDialogRequested(root.myPublicKey)
            onOpenAppSearch: {
                root.openAppSearch()
            }
            onAddRemoveGroupMemberClicked: {
                if (headerContentLoader.item && headerContentLoader.item instanceof ChatHeaderContentView) {
                    headerContentLoader.item.addRemoveGroupMember()
                }
            }
            onChatItemClicked: (id) => root.goToNextPanel()
        }
    }

    Component {
        id: communtiyColumnComponent
        CommunityColumnView {
            communitySectionModule: root.rootStore.chatCommunitySectionModule
            communityData: root.sectionItemModel
            joinedMembersCount: root.joinedMembersCount
            store: root.rootStore
            communitiesStore: root.communitiesStore
            walletAssetsStore: root.walletAssetsStore
            currencyStore: root.currencyStore
            emojiPopup: root.emojiPopup
            isPendingOwnershipRequest: root.isPendingOwnershipRequest
            ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled
            spectatedPermissionsModel: root.spectatedPermissionsModel

            onInfoButtonClicked: root.communityInfoButtonClicked()
            onManageButtonClicked: root.communityManageButtonClicked()
            onFinaliseOwnershipClicked: root.finaliseOwnershipClicked()
            onChatItemClicked: (id) => root.goToNextPanel()
            onShareOwnProfileRequested: Global.shareProfileDialogRequested(root.myPublicKey)

            // Permissions Related requests:
            onCreatePermissionRequested: root.createPermissionRequested(holdings, permissionType, isPrivate, channels)
            onRemovePermissionRequested: root.removePermissionRequested(key)
            onEditPermissionRequested: root.editPermissionRequested(key, holdings, permissionType, channels, isPrivate)
            onPrepareTokenModelForCommunityChatRequested: root.prepareTokenModelForCommunityChat(communityId, chatId)
        }
    }

    onSwiped: (previous, current) => {
        if (previous !== StatusSectionLayout.RightPanel)
            return

        // Setting timeout to let the swipe animation to complete. The workaround
        // is needed because SwipeView doesn't expose any API to detect completed
        // swipe action
        Backpressure.setTimeout(this, 300, () => {
            root.showUsersListRequested(false)
        })
    }

    onShowUsersListChanged: {
        Qt.callLater(() => {
            if (root.showUsersList)
                goToNextPanel()
        })
    }

    Component {
        id: statusStickerPackClickPopup
        StatusStickerPackClickPopup{
            onBuyClicked: root.buyStickerPackRequested(packId, price)
            onClosed: destroy()
        }
    }
}
