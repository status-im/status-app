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

    // CollectibleDetailView resolves the minting community through this; without
    // it a community collectible renders as "Unknown community".
    function getCommunityDetails(communityId) {
        for (let i = 0; i < root.model.count; ++i) {
            const community = root.model.get(i)
            if (community.id !== communityId)
                continue
            return JSON.stringify({
                id: community.id, name: community.name, image: community.image,
                color: community.color, description: community.description
            })
        }
        return "{}"
    }

    function leaveCommunity(communityId) {}
    function setCommunityMuted(communityId, muted) {}
}
