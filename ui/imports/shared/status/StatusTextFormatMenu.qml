import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Controls
import StatusQ.Core.Theme

Menu {
    id: root

    padding: 4
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Rectangle {
       color: Theme.palette.statusMenu.backgroundColor
       border.color: "transparent"
       radius: Theme.radius
       layer.enabled: true
       layer.effect: DropShadow {
           source: root.background
           horizontalOffset: 0
           verticalOffset: 4
           radius: 12
           samples: 25
           spread: 0.2
           color: Theme.palette.dropShadow
       }
    }

    contentItem: Row {
        spacing: 4
        Repeater {
            model: root.contentModel
        }
    }

    delegate: StatusFlatButton {
        width: 44
        height: 44
        display: AbstractButton.IconOnly
        icon.color: (hovered || checked) ? Theme.palette.primaryColor1: Theme.palette.directColor5
        tooltip.text: action.text
    }
}
