import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import AppLayouts.Chat.popups

SplitView {
    orientation: Qt.Vertical

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            anchors.centerIn: parent
            text: "Open menu"
            onClicked: contextMenu.open()
        }

        ThreadContextMenu {
            id: contextMenu
            anchors.centerIn: parent
            visible: true
            closePolicy: Popup.NoAutoClose
            threadLinkToCopyShare: "https://acme.org/link-to-this-thread"

            isMobile: ctrlIsMobile.checked
            followed: ctrlFollowed.checked
            muted: ctrlMuted.checked
            pinEnabled: ctrlPinEnabled.checked
            pinned: ctrlPinned.checked
            deleteEnabled: ctrlDeleteEnabled.checked

            onEditNameRequested: logs.logEvent("onEditNameRequested()")
            onFollowRequested: logs.logEvent("onFollowRequested()")
            onUnfollowRequested: logs.logEvent("onUnfollowRequested()")
            onMuteRequested: logs.logEvent("onMuteRequested", ["interval"], arguments)
            onUnmuteRequested: logs.logEvent("onUnmuteRequested()")
            onMarkAsReadRequested: logs.logEvent("onMarkAsReadRequested()")
            onPinRequested: logs.logEvent("onPinRequested()")
            onUnpinRequested: logs.logEvent("onUnpinRequested()")
            onDeleteRequested: logs.logEvent("onDeleteRequested()")

            QtObject {
                id: localAccountSensitiveSettings
                property bool showDeleteThreadWarning: true
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 300
        SplitView.preferredHeight: 300

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlFollowed
                text: "Followed"
            }
            Switch {
                id: ctrlMuted
                text: "Muted"
            }
            Switch {
                id: ctrlPinEnabled
                text: "Pin/unpin enabled"
                checked: true
            }
            Switch {
                Layout.leftMargin: 16
                id: ctrlPinned
                text: "Pinned"
                enabled: ctrlPinEnabled.checked
            }
            Switch {
                id: ctrlDeleteEnabled
                text: "Delete enabled"
                checked: true
            }
            Switch {
                id: ctrlIsMobile
                text: "Is mobile?"
            }
        }
    }
}

// category: Chat
// status: good
