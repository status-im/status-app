import QtQuick

QtObject {
    property real discordImportProgress: 0
    property bool discordImportInProgress: false
    property bool curatedCommunitiesLoading: false
    property int curatedCommunitiesRefreshError: 0

    // roster holds per community id, for pages and tests
    property var rosterHolds: ({})

    signal communityRosterAcquired(string communityId)
    signal communityRosterReleased(string communityId)

    function acquireCommunityRoster(communityId) {
        const holds = Object.assign({}, rosterHolds)
        holds[communityId] = (holds[communityId] ?? 0) + 1
        rosterHolds = holds
        communityRosterAcquired(communityId)
    }

    function releaseCommunityRoster(communityId) {
        const holds = Object.assign({}, rosterHolds)
        holds[communityId] = (holds[communityId] ?? 0) - 1
        rosterHolds = holds
        communityRosterReleased(communityId)
    }
}
