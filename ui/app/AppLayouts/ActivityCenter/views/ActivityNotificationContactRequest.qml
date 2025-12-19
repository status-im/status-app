import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import shared
import shared.panels
import utils

import "../panels"
import "../popups"
import AppLayouts.ActivityCenter.helpers

ActivityNotificationMessage {
    id: root

    readonly property bool pending: notification && notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Pending
    readonly property bool accepted: notification && notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Accepted
    readonly property bool dismissed: notification && notification.message.contactRequestState === ActivityCenterTypes.ActivityCenterContactRequestState.Dismissed

    readonly property string contactRequestId: notification && notification.message ? notification.message.id : ""

    signal blockContactRequested(string contactId, string contactRequestId)
    signal acceptContactRequested(string contactId, string contactRequestId)
    signal declineContactRequested(string contactId, string contactRequestId)

    QtObject {
        id: d

        readonly property color stateColorText: {
            if (root.accepted) {
                return Theme.palette.successColor1
            }
            if (root.dismissed) {
                return Theme.palette.dangerColor1
            }
            return Theme.palette.baseColor1
        }
        readonly property string stateText: {
            if (root.accepted) {
                return qsTr("accepted")
            }
            if (root.dismissed) {
                return qsTr("declined")
            }
            if(root.pending && root.isOutgoingMessage) {
                return qsTr("pending")
            }
            return ""
        }
    }

    maximumLineCount: 5
    messageDetails.messageText: !root.isOutgoingMessage && notification ? notification.message.messageText : ""

    contentHeaderAreaText: root.isOutgoingMessage ? qsTr("Contact request sent to %1 <font color='%2'>%3</font>").arg(contactName).arg(d.stateColorText).arg(d.stateText) :
                                                    qsTr("Contact request <font color='%1'>%2</font>").arg(d.stateColorText).arg(d.stateText)
    ctaComponent: root.pending && !root.isOutgoingMessage ? pendingCta : undefined

    onMessageClicked: {
        root.openProfilePopup(root.contactId)
    }

    Component {
        id: pendingCta

        ContactRequestCta {
            isOutgoingRequest: root.isOutgoingMessage
            pending: root.pending
            accepted: root.accepted
            dismissed: root.dismissed
            blocked: root.contactDetails && root.contactDetails.isBlocked
            onAcceptClicked: root.acceptContactRequested(root.contactId, root.contactRequestId)
            onDeclineClicked: root.declineContactRequested(root.contactId, root.contactRequestId)
            onProfileClicked: root.openProfilePopup(root.contactId)
            onBlockClicked: root.blockContactRequested(root.contactId, root.contactRequestId)
            onDetailsClicked: {
                Global.openReviewContactRequestPopup(root.contactId, null)
            }
        }
    }
}
