import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

StatusFlatRoundButton {
    type: StatusFlatRoundButton.Type.Secondary
    icon.name: "clear"
    implicitWidth: 32
    implicitHeight: 32
    icon.color: Theme.palette.directColor9
    backgroundHoverColor: "transparent"
    tooltip.text: qsTr("Clear")
}
