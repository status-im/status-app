import QtQuick

import StatusQ.Layout

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.views
import AppLayouts.stores.Messaging.Community as CommunityStores
import AppLayouts.Wallet.stores as WalletStore

import utils

JoinCommunityView {
    id: root

    required property StatusSectionLayout sectionLayout
    required property var sectionItemModel
    required property ChatStores.RootStore rootStore
    required property CommunityStores.PermissionsStore communityPermissionsStore
    required property CommunityStores.CommunityAccessStore communityAccessStore
    required property WalletStore.TokensStore tokensStore
    required property bool isInvitationPending

    function openCommunityIntro() {
        Global.communityIntroPopupRequested(root.sectionItemModel.id, root.sectionItemModel.name,
                                            root.sectionItemModel.introMessage, root.sectionItemModel.image,
                                            root.isInvitationPending)
    }

    userUID: root.sectionLayout.userUID
    sectionName: root.sectionLayout.sectionName + "_joinCommunityView"
    name: root.sectionItemModel.name
    introMessage: root.sectionItemModel.introMessage
    communityDesc: root.sectionItemModel.description
    color: root.sectionItemModel.color
    image: root.sectionItemModel.image
    membersCount: root.sectionItemModel.joinedMembersCount
    joinCommunity: true
    amISectionAdmin: root.sectionItemModel.memberRole === Constants.memberRole.owner ||
                     root.sectionItemModel.memberRole === Constants.memberRole.admin ||
                     root.sectionItemModel.memberRole === Constants.memberRole.tokenMaster
    communityItemsModel: root.rootStore.communityItemsModel
    requirementsMet: root.communityPermissionsStore.allTokenRequirementsMet
    requirementsCheckPending: root.communityAccessStore.communityPermissionsCheckOngoing
    requiresRequest: !root.sectionItemModel.amIMember
    communityHoldingsModel: root.communityPermissionsStore.becomeMemberPermissionsModel
    viewOnlyHoldingsModel: root.communityPermissionsStore.viewOnlyPermissionsModel
    viewAndPostHoldingsModel: root.communityPermissionsStore.viewAndPostPermissionsModel
    assetsModel: root.rootStore.assetsModel
    collectiblesModel: root.rootStore.collectiblesModel
    getTokenByKeyOrGroupKeyFromAllTokens: root.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens
    requestToJoinState: root.rootStore.chatCommunitySectionModule.requestToJoinState

    onRequestToJoinClicked: root.openCommunityIntro()
    onInvitationPendingClicked: root.openCommunityIntro()
}
