import QtQuick

import StatusQ.Core.Utils as StatusQUtils

import shared.stores

StatusQUtils.QObject {
    id: root

    // **
    // ** Public API for UI region:
    // **

    // All logic from this store will be related to this particular communityId
    required property var communityId

    // Whether the user has joined the community
    required property bool joined

    required property bool allChannelsAreHiddenBecauseNotPermitted

    required property int communityMemberReevaluationStatus

    // Validates temporal requirements when a user shares one or more addresses with the community.
    // This applies during both the joining flow and when editing shared addresses later.
    required property bool spectatedPermissionsCheckOngoing

    // Temporary permissions model used in join/edit address flows.
    // Reflects which permissions are met based on currently selected addresses,
    // without affecting the real community state
    required property var spectatedPermissionsModel

    // Indicates whether a permission check is currently ongoing at the community level.
    // Used to determine access to community-wide features and channels.
    required property bool communityPermissionsCheckOngoing

    // Indicates whether a permission check is in progress for the currently active chat.
    // Used to validate whether the user can read or post in a specific conversation.
    required property bool chatPermissionsCheckOngoing

    readonly property bool isMyCommunityRequestPending: d.communitiesModuleInst.isMyCommunityRequestPending(root.communityId)

    // Meant to be connected to by slot in the UI
    signal communityAccessFailed(string communityId)
    signal allSharedAddressesSigned()
    signal communityMembershipNotificationReceived()

    // Meant to be called from the UI and connected to by slot in another parent store
    signal acceptRequestToJoinCommunityRequested(string requestId, string communityId)
    signal declineRequestToJoinCommunityRequested(string requestId, string communityId)

    function spectateCommunity(communityId) {
        return d.communitiesModuleInst.spectateCommunity(communityId, "")
    }

    function updatePermissionsModel(communityId, sharedAddresses) {
        d.communitiesModuleInst.checkPermissions(communityId, JSON.stringify(sharedAddresses))
    }

    function signProfileKeypairAndAllNonKeycardKeypairs() {
        d.communitiesModuleInst.signProfileKeypairAndAllNonKeycardKeypairs()
    }

    function signSharedAddressesForKeypair(keyUid) {
        d.communitiesModuleInst.signSharedAddressesForKeypair(keyUid)
    }

    function joinCommunityOrEditSharedAddresses() {
        d.communitiesModuleInst.joinCommunityOrEditSharedAddresses()
    }

    function cleanJoinEditCommunityData() {
        d.communitiesModuleInst.cleanJoinEditCommunityData()
    }

    function cancelPendingRequest(id: string) {
        d.communitiesModuleInst.cancelRequestToJoinCommunity(id)
    }

    // TO REVIEW: This seems a workaround and preparation should be transparent for the UI consumer. Should be indeed `@internal`
    function prepareTokenModelForCommunity(publicKey) {
        d.communitiesModuleInst.prepareTokenModelForCommunity(publicKey)
    }

    // TO REVIEW: This seems a workaround and preparation should be transparent for the UI consumer. Should be indeed `@internal`
    function prepareTokenModelForCommunityChat(publicKey, chatId) {
        d.communitiesModuleInst.prepareTokenModelForCommunityChat(publicKey, chatId)
    }

    // TO REVIEW: This seems a workaround and preparation should be transparent for the UI consumer. Should be indeed `@internal`
    function prepareKeypairsForSigning(communityId, ensName, addressesToShare = [], airdropAddress = "", editMode = false) {
        d.communitiesModuleInst.prepareKeypairsForSigning(communityId, ensName, JSON.stringify(addressesToShare), airdropAddress, editMode)
    }

    // **
    // ** Stores' internal API region:
    // **

    // Indicates whether the current community module is initialized and available.
    required property bool isModuleReady

    // Private property used to define context properties asignements and other private stuff.
    QtObject {
        id: d

        readonly property var mainModuleInst: mainModule
        readonly property var communitiesModuleInst: communitiesModule
        readonly property var localAccountSensitiveSettingsInst: localAccountSensitiveSettings
    }

    readonly property Connections mainModuleInstConnections: Connections {
        target: d.mainModuleInst
        enabled: root.isModuleReady

        // TODO: Review this trigger on the business-logic side since it will not be the
        // one conditioning any UI navigation explicitly (it seems it's related to some OS notifications)
        function onOpenCommunityMembershipRequestsView(sectionId: string) {
            if(root.mySectionId !== sectionId)
                return

            root.communityMembershipNotificationReceived()
        }
    }

    readonly property Connections communitiesModuleConnections: Connections {
        target: d.communitiesModuleInst

        function onCommunityAccessFailed(communityId: string, error: string) {
            root.communityAccessFailed(communityId)
        }

        function onAllSharedAddressesSigned() {
            root.allSharedAddressesSigned()
        }
    }
}
