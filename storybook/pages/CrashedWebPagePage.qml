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

// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=15747-76304

// category: Views
// status: good
