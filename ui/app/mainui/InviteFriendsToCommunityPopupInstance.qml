import AppLayouts.Communities.helpers
import AppLayouts.Communities.popups
import AppLayouts.Communities.stores as CommunitiesStores

InviteFriendsToCommunityPopup {
    id: invitePopup

    required property CommunitiesStores.CommunitiesStore communitiesStore

    // marks the friends who are already members
    readonly property RosterHolder rosterHolder: RosterHolder {
        communitiesStore: invitePopup.communitiesStore
        communityId: invitePopup.community?.id ?? ""
    }
}
