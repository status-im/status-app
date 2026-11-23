import QtQuick

import AppLayouts.Communities.helpers
import AppLayouts.Communities.popups
import AppLayouts.Communities.stores as CommunitiesStores

CommunityMemberMessagesPopup {
    id: root

    required property CommunitiesStores.CommunitiesStore communitiesStore

    // mention names in the messages come from the roster
    readonly property RosterHolder rosterHolder: RosterHolder {
        communitiesStore: root.communitiesStore
        communityId: root.rootStore?.communityId ?? ""
    }
}
