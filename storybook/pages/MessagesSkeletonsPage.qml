import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Chat.panels

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
                    Layout.preferredWidth: panelsRow.landscape ? 306 : -1
                    Layout.fillWidth: !panelsRow.landscape
                    Layout.fillHeight: true

                    onShareOwnProfileRequested: logs.logEvent("shareOwnProfileRequested")
                    onStartChatClicked: logs.logEvent("startChatClicked")
                }

                MessagesChatSkeleton {
                    visible: panelsRow.landscape
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Theme.xlPadding
                    Layout.rightMargin: Theme.xlPadding
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

            RowLayout {
                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 320
                    to: 1000
                    value: 455
                }
                Label { text: Math.round(ctrlWidth.value) }
            }

            Item { Layout.fillWidth: true }
        }
    }
}

// category: Panels
