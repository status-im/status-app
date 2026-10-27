import QtQml

import StatusQ.Core.Utils

import AppLayouts.Communities.stores

// Keeps a community's member roster loaded while it exists and is active. The
// roster loads on its first holder and is dropped about two minutes after its
// last one goes.
QObject {
    id: root

    required property CommunitiesStore communitiesStore

    property string communityId
    property bool active: true

    readonly property bool holding: holder.holding

    ResourceHolder {
        id: holder

        key: root.communityId
        active: root.active

        onAcquireRequested: key => root.communitiesStore.acquireCommunityRoster(key)
        // the store is gone only while the whole app tears down
        onReleaseRequested: key => root.communitiesStore?.releaseCommunityRoster(key)
    }
}
