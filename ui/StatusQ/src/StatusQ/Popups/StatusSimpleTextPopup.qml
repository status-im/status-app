pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    width: 600
    padding: 0
    standardButtons: Dialog.Ok

    property alias content: contentText

    signal linkActivated(string link)

    StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        StatusBaseText {
            id: contentText
            width: scrollView.availableWidth
            wrapMode: Text.Wrap
            onLinkActivated: (link) => root.linkActivated(link)
        }
    }
}
