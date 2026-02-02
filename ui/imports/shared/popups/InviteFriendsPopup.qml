import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import shared.controls
import utils

StatusDialog {
    id: root

    title: qsTr("Download Status link")
    standardButtons: Dialog.Ok
    width: 400

    contentItem: Row {
        spacing: Theme.halfPadding
        StatusBaseText {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Get Status at %1").arg(Constants.externalStatusLinkWithHttps)
        }
        CopyButton {
            anchors.verticalCenter: parent.verticalCenter
            textToCopy: Constants.downloadLink
        }
    }
}
