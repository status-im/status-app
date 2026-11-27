pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Popups.Dialog

StatusAdaptiveDialog {
    id: root

    property bool noAccess: false

    objectName: "deepLinkErrorDialog"
    title: noAccess ? qsTr("No access") : qsTr("Content unavailable")
    showHeaderDivider: false

    contentComponent: StatusBaseText {
        objectName: "deepLinkErrorDescription"
        text: root.noAccess
              ? qsTr("You don't have permission to open this link. Get access to view it.")
              : qsTr("The content couldn't be retrieved or may have been deleted.")
        wrapMode: Text.Wrap
    }

    footerRightButtons: ObjectModel {
        StatusButton {
            objectName: "deepLinkErrorDismissButton"
            type: StatusButton.Primary
            text: qsTr("Got it")
            onClicked: root.accept()
        }
    }
}
