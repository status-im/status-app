import QtQuick

// Same public surface as the real CommunityAccessStore, but every input is a
// plain settable property (no nim context modules behind it)
QtObject {
    property var communityId
    property bool isModuleReady: true
    property bool joined: false
    property bool allChannelsAreHiddenBecauseNotPermitted: false
    property int communityMemberReevaluationStatus: 0
    property bool spectatedPermissionsCheckOngoing: false
    property var spectatedPermissionsModel: null
    property bool communityPermissionsCheckOngoing: false
    property bool chatPermissionsCheckOngoing: false
    property bool isMyCommunityRequestPending: false

    signal communityAccessFailed(string communityId)
    signal allSharedAddressesSigned()
    signal communityMembershipNotificationReceived()
    signal acceptRequestToJoinCommunityRequested(string requestId, string communityId)
    signal declineRequestToJoinCommunityRequested(string requestId, string communityId)

    function spectateCommunity(communityId) {}
    function updatePermissionsModel(communityId, sharedAddresses) {}
    function signSharedAddressesForKeypair(keyUid) {}
    function joinCommunityOrEditSharedAddresses() {}
    function cleanJoinEditCommunityData() {}
    function cancelPendingRequest(id) {}
    function prepareTokenModelForCommunity(publicKey) {}
    function prepareTokenModelForCommunityChat(publicKey, chatId) {}
    function prepareKeypairsForSigning(communityId, ensName, addressesToShare, airdropAddress, editMode) {}
}
