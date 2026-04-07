pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

StatusFlatRoundButton {
    type: StatusFlatRoundButton.Type.Secondary
    icon.name: "clear"
    icon.width: 16
    icon.height: 16
    implicitWidth: 24
    implicitHeight: 24
    icon.color: Theme.palette.directColor9
    backgroundHoverColor: "transparent"
    tooltip.text: qsTr("Clear")
}
