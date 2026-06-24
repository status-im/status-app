import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import StatusQ.Core.Theme

import AppLayouts.Chat.panels

SplitView {
    orientation: Qt.Vertical

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: Theme.palette.statusAppLayout.backgroundColor

        ChatAnchorButtonsPanel {
            id: panel

            anchors.centerIn: parent

            mentionsCount: mentionsCountSlider.value
            recentMessagesCount: recentMessagesCountSlider.value

            onMentionsButtonClicked: mentionsCountSlider.value = mentionsCountSlider.value - 1
            onRecentMessagesButtonClicked: recentMessagesCountSlider.value = 0
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 250

        ColumnLayout {
            Row {
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "unread mentions:"
                }

                Slider {
                    id: mentionsCountSlider
                    value: 1
                    from: 0
                    to: 200
                }
            }

            Row {
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "recent messages:"
                }

                Slider {
                    id: recentMessagesCountSlider
                    value: 0
                    from: 0
                    to: 200
                }
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/file/Mr3rqxxgKJ2zMQ06UAKiWL/%F0%9F%92%AC-Chat%E2%8E%9CDesktop?node-id=14632-460085&t=SGTU2JeRA8ifbv2E-0
