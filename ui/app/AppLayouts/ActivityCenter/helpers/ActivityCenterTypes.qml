import QtQuick

QtObject {
    id: root

    enum ActivityCenterMembershipStatus {
        None = 0,
        Pending = 1,
        Accepted = 2,
        Declined = 3,
        AcceptedPending = 4,
        DeclinedPending = 5
    }

    enum ActivityCenterContactRequestState {
        Pending = 1,
        Accepted = 2,
        Dismissed = 3
    }

    enum ActivityCenterNotificationType {
        NoType = 0,
        NewOneToOne = 1,
        NewPrivateGroupChat = 2,
        Mention = 3,
        Reply = 4,
        ContactRequest = 5,
        CommunityInvitation = 6,
        CommunityRequest = 7,
        CommunityMembershipRequest = 8,
        CommunityKicked = 9,
        ContactVerification = 10,
        ContactRemoved = 11,
        NewKeypairAddedToPairedDevice = 12,
        OwnerTokenReceived = 13,
        OwnershipReceived = 14,
        OwnershipLost = 15,
        OwnershipFailed = 16,
        OwnershipDeclined = 17,
        ShareAccounts = 18,
        CommunityTokenReceived = 19,
        FirstCommunityTokenReceived = 20,
        CommunityBanned = 21,
        CommunityUnbanned = 22,
        NewInstallationReceived = 23,
        NewInstallationCreated = 24,
        BackupSyncingFetching = 25, // Deprecated
        BackupSyncingSuccess = 26, // Deprecated
        BackupSyncingPartialFailure = 27, // Deprecated
        BackupSyncingFailure = 28, // Deprecated
        ActivityCenterNotificationTypeNews = 29
    }

    enum ActivityCenterGroup {
        All = 0,
        Mentions = 1,
        Replies = 2,
        Membership = 3,
        Admin = 4,
        ContactRequests = 5,
        IdentityVerification = 6,
        Transactions = 7,
        System = 8,
        NewsMessage = 9
    }
}
