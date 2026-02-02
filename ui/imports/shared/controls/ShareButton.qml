import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

StatusIcon {
    id: root

    required property string textToShare

    readonly property bool hovered: mouseArea.containsMouse

    icon: SQUtils.Utils.isIOS ? "share-ios" : "share-android"
    color: mouseArea.containsMouse? Theme.palette.primaryColor1 : Theme.palette.baseColor1

    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: ShareUtils.shareText(root.textToShare)
    }
}
