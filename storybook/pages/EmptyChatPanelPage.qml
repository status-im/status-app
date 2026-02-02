import QtQuick

import StatusQ.Core.Theme

import Storybook

import AppLayouts.Chat.panels

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.background

        EmptyChatPanel {
            anchors.fill: parent
            onShareChatKeyClicked: console.log("EmptyChatPanel::onShareChatKeyClicked")
        }
    }
}

// category: Panels
// status: good
