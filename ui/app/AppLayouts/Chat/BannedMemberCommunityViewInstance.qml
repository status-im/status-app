import StatusQ.Layout

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.views

BannedMemberCommunityView {
    id: root

    required property StatusSectionLayout sectionLayout
    required property var sectionItemModel
    required property ChatStores.RootStore rootStore

    userUID: root.sectionLayout.userUID
    sectionName: root.sectionLayout.sectionName + "_bannedMembers"
    name: root.sectionItemModel.name
    communityDesc: root.sectionItemModel.description
    color: root.sectionItemModel.color
    image: root.sectionItemModel.image
    membersCount: root.sectionItemModel.joinedMembersCount
    communityItemsModel: root.rootStore.communityItemsModel
}
