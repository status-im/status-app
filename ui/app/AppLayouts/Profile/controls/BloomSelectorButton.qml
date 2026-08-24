import QtQuick

import StatusQ.Core.Theme
import StatusQ.Controls

StatusRadioButton {
    id: root

    implicitWidth: 130
    implicitHeight: 120
    padding: Theme.halfPadding
    background: Rectangle {
        radius: Theme.radius
        border.color: root.hovered || root.checked ? Theme.palette.primaryColor1 : Theme.palette.border
        border.width: 1
        color: StatusColors.transparent
    }
}
