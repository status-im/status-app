import QtQuick

NotificationAdaptorBase {
    id: root

    /*!
        Resolves community details for a given community id.

        This function must be provided by the consumer of the adaptor.

        @param communityId [string]
        @return            [object|null] Community details (e.g. name, image)
    */
    property var getCommunityDetails: function(communityId) { return null }

    QtObject {
        id: d

        readonly property var community: (notification) ? root.getCommunityDetails(notification.communityId) : null
    }

    // -------------------------
    // Avatar related
    // -------------------------
    avatarSource: d.community?.image ?? ""
    isCircularAvatar: true
    isAvatarClickable: false

    // -------------------------
    // Context row related
    // -------------------------
    context.contextPrimaryName: d.community?.name ?? ""
    context.contextImageSource: "communities"

    // -------------------------
    // Navigation related
    // -------------------------
    redirectToSection: true
}
