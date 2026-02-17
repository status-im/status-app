import QtQuick
import QtQuick.Controls

import StatusQ.Popups
import StatusQ.Core.Theme

StatusMenu {
    id: root

    required property string url
    required property string name

    signal openInNewTab(url url)
    signal editBookmarkRequested(string url, string name)
    signal deleteBookmarkRequested(string url)

    background: Rectangle {
        color: Theme.palette.statusMenu.backgroundColor
        radius: Theme.radius
    }

    StatusAction {
        text: qsTr("Open in new Tab")
        icon.name: "generate_account"
        onTriggered: root.openInNewTab(root.url)
    }

    StatusMenuSeparator {}

    StatusAction {
        text: qsTr("Edit")
        icon.name: "edit_pencil"
        onTriggered: root.editBookmarkRequested(root.url, root.name)
    }

    StatusAction {
        text: qsTr("Remove")
        icon.name: "remove"
        type: StatusAction.Type.Danger
        onTriggered: root.deleteBookmarkRequested(root.url)
    }
}
