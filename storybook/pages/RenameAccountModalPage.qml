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

import AppLayouts.Profile.popups

Item {
    id: root

    PopupBackground {
        anchors.fill: parent

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: popup.open()
        }

        RenameAccountModal {
            id: popup
            anchors.centerIn: parent
            visible: true
            accountName: "Sample Account"
            accountColorId: Constants.walletAccountColors.orange
        }
    }
}

// category: Popups
// status: good
