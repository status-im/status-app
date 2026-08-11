import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Chat.panels
import AppLayouts.Communities.panels

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: ctrlWidth.value
            height: parent.height - 2 * Theme.padding
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            RowLayout {
                id: panelsRow

                readonly property bool landscape: ctrlLandscape.checked

                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: Theme.padding

                MessagesListSkeleton {
                    visible: !ctrlCommunity.checked
                    Layout.preferredWidth: panelsRow.landscape ? 306 : -1
                    Layout.fillWidth: !panelsRow.landscape
                    Layout.fillHeight: true

                    onShareOwnProfileRequested: logs.logEvent("shareOwnProfileRequested")
                    onStartChatClicked: logs.logEvent("startChatClicked")
                }

                CommunityChannelsSkeleton {
                    visible: ctrlCommunity.checked
                    Layout.preferredWidth: panelsRow.landscape ? 306 : -1
                    Layout.fillWidth: !panelsRow.landscape
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    visible: panelsRow.landscape
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Theme.xlPadding
                    Layout.rightMargin: Theme.xlPadding
                    spacing: Theme.padding

                    ChatHeaderSkeleton {
                        Layout.preferredHeight: 40
                    }

                    MessagesChatSkeleton {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                MembersListSkeleton {
                    visible: panelsRow.landscape && ctrlMembers.checked
                    Layout.preferredWidth: 250
                    Layout.fillHeight: true
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 100
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        RowLayout {
            anchors.fill: parent
            spacing: Theme.bigPadding

            Switch {
                id: ctrlLandscape
                text: "Landscape (list + chat)"
            }

            Switch {
                id: ctrlCommunity
                text: "Community list"
            }

            Switch {
                id: ctrlMembers
                text: "Members panel"
            }

            RowLayout {
                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 320
                    to: 1200
                    value: 455
                }
                Label { text: Math.round(ctrlWidth.value) }
            }

            Item { Layout.fillWidth: true }
        }
    }
}

// category: Skeletons
