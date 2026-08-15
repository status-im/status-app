// Mock of src/app/modules/main/communities/view.nim
//
// Not listed in the design's mock inventory, but the real WalletAssetsStore and
// CollectiblesStore both join against communitiesModule.model to resolve
// community name/image for community assets and collectibles.
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "communitiesModule"

    // id / name / image / description / color
    property ListModel model: ListModel {}
    property ListModel tags: ListModel {}

    function leaveCommunity(communityId) {}
    function setCommunityMuted(communityId, muted) {}
}
