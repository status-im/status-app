import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls

StatusIcon {
    id: root

    property string tooltipText

    readonly property bool hovered: hoverHandler.hovered

    signal clicked()

    TapHandler {
        grabPermissions: PointerHandler.ApprovesTakeOverByHandlersOfDifferentType
        onTapped: root.clicked()
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }

    StatusLazyToolTip {
        enabled: !!text
        text: root.tooltipText
    }
}
