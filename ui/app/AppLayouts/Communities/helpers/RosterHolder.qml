import QtQml

import StatusQ.Core.Utils

import AppLayouts.Communities.stores

// Keeps a community's member roster loaded while it exists and is active: it
// acquires on activation and releases on deactivation, on a community change
// and on destruction. The roster loads on its first holder and is dropped about
// two minutes after its last one goes.
QObject {
    id: root

    required property CommunitiesStore communitiesStore

    property string communityId
    property bool active: true

    readonly property bool holding: d.heldCommunityId !== ""

    QtObject {
        id: d

        property bool completed
        property string heldCommunityId

        readonly property string wantedCommunityId: completed && root.active ? root.communityId : ""
        onWantedCommunityIdChanged: sync()

        function sync() {
            if (heldCommunityId === wantedCommunityId)
                return
            release()
            heldCommunityId = wantedCommunityId
            if (heldCommunityId !== "")
                root.communitiesStore.acquireCommunityRoster(heldCommunityId)
        }

        function release() {
            if (heldCommunityId === "")
                return
            // the store is gone only while the whole app tears down
            root.communitiesStore?.releaseCommunityRoster(heldCommunityId)
            heldCommunityId = ""
        }
    }

    Component.onCompleted: d.completed = true
    Component.onDestruction: d.release()
}
