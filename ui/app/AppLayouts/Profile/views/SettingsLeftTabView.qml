import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import utils
import shared.popups

import AppLayouts.Profile.controls

Item {
    id: root

    property alias model: settingsList.model

    signal menuItemClicked(string subsection)

    property int settingsSubsection: -1

    StatusNavigationPanelHeadline {
        id: title
        text: qsTr("Settings")
        anchors.top: parent.top
        anchors.topMargin: 2 * Theme.bigPadding
        anchors.left: parent.left
        anchors.leftMargin: Theme.bigPadding
    }

    SettingsList {
        id: settingsList

        currenctSubsection: root.settingsSubsection

        anchors.right: parent.right
        anchors.left: parent.left
        anchors.top: title.bottom
        anchors.bottom: parent.bottom

        anchors.topMargin: Theme.bigPadding
        anchors.bottomMargin: Theme.bigPadding

        onClicked: function(subsection) {
            if (subsection === Constants.settingsSubsection.backUpSeed) {
                Global.openBackUpSeedPopup()
                return
            }

            if (subsection === Constants.settingsSubsection.signout) {
                Global.quitAppRequested()
                return
            }

            root.menuItemClicked(subsection)
        }
    }
}
