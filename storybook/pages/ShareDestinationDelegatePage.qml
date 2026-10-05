import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import utils
import mainui

SplitView {
    id: root

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 800
            color: Theme.palette.statusListItem.backgroundColor
            border.color: Theme.palette.baseColor2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.halfPadding
                spacing: Theme.halfPadding

                ShareDestinationDelegate {
                    objectName: "shareDestinationDelegate_contact"
                    Layout.fillWidth: true
                    chatId: "0x041510eb18dc163b548243189751613df0679bf429074a4bd99c60c550e183a21c4802c033355d007be275404a1f526aed25051835a98831810d88df92041cd30b"
                    name: "Darrell Steward"
                    color: ""
                    colorId: 3
                    icon: ""
                    emoji: ""
                    chatType: Constants.chatType.oneToOne
                    membersCount: 0
                    onlineStatus: ctrlOnline.checked ? 1 : 0
                    sectionName: "Chat"
                    checked: ctrlChecked.checked
                    onToggled: chatId => logs.logEvent("toggled: " + chatId)
                }

                ShareDestinationDelegate {
                    Layout.fillWidth: true
                    chatId: "group-travel"
                    name: "Travel Days"
                    color: "#7cda00"
                    colorId: 2
                    icon: ""
                    emoji: "🏔️"
                    chatType: Constants.chatType.privateGroupChat
                    membersCount: ctrlMembers.value
                    onlineStatus: 0
                    sectionName: "Chat"
                    checked: ctrlChecked.checked
                    onToggled: chatId => logs.logEvent("toggled: " + chatId)
                }

                ShareDestinationDelegate {
                    Layout.fillWidth: true
                    chatId: "channel-pets"
                    name: "pets"
                    color: "#887af9"
                    colorId: 4
                    icon: ""
                    emoji: "🐶"
                    chatType: Constants.chatType.communityChat
                    membersCount: 0
                    onlineStatus: 0
                    sectionName: "Status"
                    checked: ctrlChecked.checked
                    onToggled: chatId => logs.logEvent("toggled: " + chatId)
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            CheckBox { id: ctrlChecked; text: "checked" }
            CheckBox { id: ctrlOnline; text: "contact online"; checked: true }
            RowLayout {
                Label { text: "members" }
                SpinBox { id: ctrlMembers; from: 0; to: 999; value: 25 }
            }
        }
    }
}

// category: Panels
