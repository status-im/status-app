import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import utils
import shared.popups

import AppLayouts.Profile.controls

Item {
    id: root

    property alias model: settingsList.model

    signal menuItemClicked(var event)

    property alias settingsSubsection: settingsList.currenctSubsection

    StatusNavigationPanelHeadline {
        id: title
        text: qsTr("Settings")
        anchors.top: parent.top
        anchors.topMargin: Theme.padding
        anchors.left: parent.left
        anchors.leftMargin: Theme.bigPadding
    }

    SettingsList {
        id: settingsList

        anchors.right: parent.right
        anchors.left: parent.left
        anchors.top: title.bottom
        anchors.bottom: parent.bottom

        anchors.topMargin: Theme.bigPadding
        anchors.bottomMargin: Theme.padding

        leftMargin: Constants.primaryNavSidebarHandleWidth
        rightMargin: Theme.padding
        bottomMargin: Theme.bigPadding

        onClicked: function(subsection) {
            if (subsection === Constants.settingsSubsection.backUpSeed) {
                Global.openBackUpSeedPopup()
                return
            }

            const event = { accepted: false, item: subsection };

            root.menuItemClicked(event)

            if (event.accepted)
                return

            if (subsection === Constants.settingsSubsection.signout)
                return Global.quitAppRequested()

            root.settingsSubsection = subsection
        }
    }
}
