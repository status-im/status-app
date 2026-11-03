import QtQuick

import AppLayouts.stores.Messaging.Community

import StatusQ.Core.Utils as StatusQUtils

StatusQUtils.QObject {
    id: root

    // **
    // ** Public API for UI region:
    // **

    readonly property ThreadReplyStore threadReplyStore: ThreadReplyStore {}

    readonly property MessagingSettingsStore messagingSettingsStore: MessagingSettingsStore {}

    // Dynamic `CommunityRootStore` instance creation logic.
    // Each `CommunityRootStore` is owned by the delegate that needs it and gets destroyed with it (clear ownership).
    function createCommunityRootStore(parent, communityId) {
        const store = communityRootStoreComponent.createObject(parent, { communityId: communityId })

        if (!store) {
            console.error("Failed to create CommunityRootStore! Context might be invalid.")
        }

        return store
    }

    // **
    // ** Stores' internal API region:
    // **

    Component {
        id: communityRootStoreComponent

        CommunityRootStore {
            Component.onCompleted: console.log("Store created for", communityId)
            Component.onDestruction: console.log("Store for", communityId, "destroyed")
        }
    }
}
