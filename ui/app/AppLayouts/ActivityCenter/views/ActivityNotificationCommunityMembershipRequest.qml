import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared
import shared.panels
import utils
import shared.views.chat

import "../controls"
import "../panels"
import AppLayouts.ActivityCenter.helpers

ActivityNotificationMessage {
    id: root

    required property var community


    // Community access requests:
    signal acceptRequestToJoinCommunityRequested(string requestId, string communityId)
    signal declineRequestToJoinCommunityRequested(string requestId, string communityId)

    signal setActiveCommunityRequested(string communityId)


    QtObject {
        id: d

        readonly property int membershipStatus: notification && notification.membershipStatus ? notification.membershipStatus : ActivityCenterTypes.ActivityCenterMembershipStatus.None
        readonly property bool pending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Pending
        readonly property bool accepted: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Accepted
        readonly property bool declined: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Declined
        readonly property bool acceptedPending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.AcceptedPending
        readonly property bool declinedPending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.DeclinedPending

        readonly property color stateColorText: {
            if (d.accepted) {
                return Theme.palette.successColor1
            }
            if (d.declined) {
                return Theme.palette.dangerColor1
            }
            return Theme.palette.baseColor1
        }
        readonly property string stateText: {
            if (d.accepted) {
                return qsTr("accepted")
            }
            if (d.declined) {
                return qsTr("declined")
            }
            if (d.acceptedPending) {
                return qsTr("accepted pending")
            }
            if (d.declinedPending) {
                return qsTr("declined pending")
            }
            return ""
        }
    }

    messageDetails.messageText: qsTr("Requested membership in your community <font color='%1'>%2</font>").arg(d.stateColorText).arg(d.stateText)
    messageDetails.sender.profileImage.name: root.contactDetails ? root.contactDetails.thumbnailImage : ""
    messageDetails.sender.profileImage.assetSettings.isImage: true
    messageDetails.sender.profileImage.pubkey: notification ? notification.author : ""
    messageDetails.sender.profileImage.color:
        Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(notification ? notification.author : "")]

    badgeComponent: CommunityBadge {
        communityName: community ? community.name : ""
        communityImage: community ? community.image : ""
        communityColor: community ? community.color : "black"

        onCommunityNameClicked: {
            root.setActiveCommunityRequested(notification.communityId)
            root.closeActivityCenter()
        }
        Layout.maximumWidth: parent.width
    }

    ctaComponent: d.pending ? ctaPendingComponent : undefined

    Component {
        id: ctaPendingComponent
        //TODO: Get backend value. If the membersip is in acceptedPending or declinedPending state, another user can't accept or decline the request
        //Only the user who requested can cancel the request
        //ctaAllowed: true

        RowLayout {
            spacing: Theme.halfPadding
            StatusFlatButton {
                icon.name: "checkmark-circle"
                icon.color: Theme.palette.successColor1
                onClicked: root.acceptRequestToJoinCommunityRequested(notification.id, notification.communityId)
                font.pixelSize: Theme.additionalTextSize
                verticalPadding: 4
                horizontalPadding: 4
            }

            StatusFlatButton {
                icon.name: "close-circle"
                icon.color: Theme.palette.dangerColor1
                onClicked: root.declineRequestToJoinCommunityRequested(notification.id, notification.communityId)
                font.pixelSize: Theme.additionalTextSize
                verticalPadding: 4
                horizontalPadding: 4
            }
        }
    }
}
