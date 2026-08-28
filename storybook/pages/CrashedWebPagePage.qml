import QtQuick

import StatusQ.Core.Theme

import Storybook

import AppLayouts.Browser.views

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.background

        CrashedWebPage {
            anchors.fill: parent
            onReloadRequested: console.info("CrashedWebPage::onReloadRequested")
        }
    }
}

// category: Views
// status: good
