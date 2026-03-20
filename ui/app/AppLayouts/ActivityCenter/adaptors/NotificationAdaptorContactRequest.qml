import QtQuick
import StatusQ
import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.helpers

import utils

/*!
    Adaptor for contact request notifications.

    No context needed.
*/
NotificationAdaptorMessenger {
    id: root

    QtObject {
        id: d

        readonly property bool accepted: notification &&
                                         notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Accepted
        readonly property bool declined: notification &&
                                         notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Dismissed
        readonly property bool pending: notification &&
                                        notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Pending

        readonly property string contactRequestId: notification && notification.message ? notification.message.id : ""
    }

    // -------------------------
    // Avatar related
    // -------------------------

    badgeIconName:  {
        if(d.accepted)
            return "action-check"
        if(d.declined)
            return "action-decline"
        if(d.pending && root.isOutgoingMessage)
            return "action-sent"
        if(d.pending && !root.isOutgoingMessage)
            return "action-add"
    }

    // -------------------------
    // Action text
    // -------------------------

    actionText: {
        if(root.isOutgoingMessage) {
            if(d.accepted)
                return "<font color='%1'>".arg(Theme.palette.successColor1) + qsTr("Accepted your contact request") + "</font>"

            if(d.declined)
                return "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Declined your contact request") + "</font>"

            if(d.pending)
                return qsTr("You’ve sent request to contact")

        }
        else {
            if(d.accepted)
                return "<font color='%1'>".arg(Theme.palette.successColor1) + qsTr("Contact request accepted") + "</font>"

            if(d.declined)
                return "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Contact request declined") + "</font>"

            if(d.pending) {
                return qsTr("New contact request")
            }
        }
    }

    // -------------------------
    // Content block related
    // -------------------------
    content: !root.isOutgoingMessage ? (notification && notification.message
                                        ? notification.message.messageText :  "") : ""

    // -------------------------
    // Quick actions related
    // -------------------------
    showQuickActions: !root.isOutgoingMessage && d.pending
    actionId: d.contactRequestId

    // -------------------------
    // Navigation related
    // -------------------------
    redirectToDetails: !d.pending // Otherwise, the redirection will be to the avatar information
}
