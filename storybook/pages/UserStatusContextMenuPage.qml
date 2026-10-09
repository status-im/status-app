import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import Models
import Storybook

import SortFilterProxyModel

import utils
import shared.popups

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: d
        property int currentUserStatus: Constants.currentUserStatus.automatic
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            anchors.centerIn: parent
            text: "Open menu"
            onClicked: contextMenu.open()
        }

        UserStatusContextMenu {
            id: contextMenu
            anchors.centerIn: bottomSheet ? undefined : parent
            visible: true
            modal: false
            closePolicy: Popup.NoAutoClose
            directParent: Overlay.overlay
            isMobile: ctrlIsMobile.checked
            compressedPubKey: "zxcvdeadbeef"
            emojiHash: ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮","🤷🏻‍♂️", "🤦🏻",
                "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
            name: "John Doe"
            headerIcon: ctrlHasIcon.checked ? ModelsData.icons.cryptPunks : ""
            colorId: Math.floor(Math.random() * Theme.palette.userCustomizationColors.length)
            usesDefaultName: true//false
            bio: ModelsData.descriptions.mediumLoremIpsum
            currentUserStatus: d.currentUserStatus
            onViewProfileRequested: logs.logEvent("onViewProfileRequested")
            onCopyLinkRequested: logs.logEvent("onCopyLinkRequested")
            onShareOwnProfileRequested: logs.logEvent("onShareOwnProfileRequested")
            onSettingsRequested: logs.logEvent("onSettingsRequested")
            onSetCurrentUserStatusRequested: function(status) {
                logs.logEvent("onSetCurrentUserStatusRequested", ["status"], arguments)
                d.currentUserStatus = status
            }
            onQuitRequested: logs.logEvent("onQuitRequested")
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlIsMobile
                text: "Is mobile"
            }
            Switch {
                id: ctrlHasIcon
                text: "Has icon"
                checked: true
            }
        }
    }
}

// category: Popups
// status: good
