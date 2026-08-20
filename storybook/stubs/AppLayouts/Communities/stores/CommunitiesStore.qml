import QtQuick

QtObject {
    property real discordImportProgress: 0
    property bool discordImportInProgress: false

    // Same shape as the real store: parse what communitiesModule returns. The
    // wallet collectible detail resolves the minting community through it.
    function getCommunityDetailsAsJson(communityId) {
        try {
            return JSON.parse(communitiesModule.getCommunityDetails(communityId))
        } catch (e) {
            return {}
        }
    }
}
