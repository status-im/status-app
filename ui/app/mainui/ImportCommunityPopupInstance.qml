import QtQuick

import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores

import shared.popups

ImportCommunityPopup {
    id: root

    required property MessagingStores.MessagingRootStore messagingRootStore

    property CommunityStores.CommunityRootStore communityRootStore: messagingRootStore.createCommunityRootStore(this, root.communityId)
    readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                     communityRootStore.communityAccessStore : null
}
