import QtQml

import StatusQ
import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import shared.controls.chat.menuItems
import shared.popups

import utils

StatusMenu {
    id: root

    required property bool isMobile
    required property bool followed
    required property bool muted
    required property bool pinned
    required property bool pinEnabled
    required property string threadLinkToCopyShare
    required property bool deleteEnabled

    signal editNameRequested()
    signal followRequested()
    signal unfollowRequested()
    signal muteRequested(int interval) // Constants.MutingVariations.XXX
    signal unmuteRequested()
    signal markAsReadRequested()
    signal pinRequested()
    signal unpinRequested()
    signal deleteRequested()

    StatusAction {
        objectName: "threadContextMenu_editName"
        text: qsTr("Edit name")
        icon.name: "edit_pencil"
        onTriggered: root.editNameRequested()
    }

    StatusAction {
        objectName: "threadContextMenu_follow"
        text: root.followed ? qsTr("Unfollow") : qsTr("Follow")
        icon.name: "checkmark"
        onTriggered: root.followed ? root.unfollowRequested() : root.followRequested()
    }

    MuteChatMenuItem {
        objectName: "threadContextMenu_muteThread"
        title: qsTr("Mute thread")
        enabled: !root.muted
        onMuteTriggered: interval => root.muteRequested(interval)
    }

    StatusAction {
        objectName: "threadContextMenu_unmuteThread"
        text: qsTr("Unmute thread")
        enabled: root.muted
        icon.name: "notification"
        onTriggered: root.unmuteRequested()
    }

    StatusAction {
        objectName: "threadContextMenu_markAsRead"
        text: qsTr("Mark as read")
        icon.name: "checkmark-circle"
        onTriggered: root.markAsReadRequested()
    }

    StatusSuccessAction {
        objectName: "threadContextMenu_copyShare"

        readonly property string shareIcon: root.isMobile
                                            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
                                            : "copy"
        readonly property string shareLabel: root.isMobile ? qsTr("Share link") : qsTr("Copy link")

        icon.name: shareIcon
        text: shareLabel
        successText: qsTr("Copied")
        autoDismissMenu: true
        timeout: root.isMobile ? 0 : 1250
        onTriggered: ShareUtils.shareText(root.threadLinkToCopyShare) // clipboard on desktop; native share sheet on mobile
    }

    StatusAction {
        objectName: "threadContextMenu_pin"
        text: root.pinned ? qsTr("Unpin from list") : qsTr("Pin to list")
        enabled: root.pinEnabled
        icon.name: root.pinned ? "unpin" : "pin"
        onTriggered: root.pinned ? root.unpinRequested() : root.pinRequested()
    }

    StatusMenuSeparator {
        visible: actionDelete.enabled
    }

    StatusAction {
        id: actionDelete
        objectName: "threadContextMenu_delete"
        text: qsTr("Delete")
        enabled: root.deleteEnabled
        icon.name: "delete"
        type: StatusAction.Type.Danger
        onTriggered: {
            if (localAccountSensitiveSettings.showDeleteThreadWarning)
                Global.openPopup(confirmDeletePopupComponent)
            else
                root.deleteRequested()
        }
    }

    Component {
        id: confirmDeletePopupComponent
        ConfirmationDialog {
            objectName: "threadContextMenu_confirmDeletePopup"
            visible: true
            title: qsTr("Delete this thread?")
            confirmButtonLabel: qsTr("Delete")
            confirmationText: qsTr("Are you sure you want to delete this thread? It may remain visible on other participants' devices.")
            destroyOnClose: true
            doNotShowAgainOptionVisible: true
            onAboutToShow: doNotShowAgainChecked = false
            onConfirmButtonClicked: {
                if (doNotShowAgainChecked) {
                    localAccountSensitiveSettings.showDeleteThreadWarning = false
                }
                root.deleteRequested()
                close()
            }
        }
    }
}
