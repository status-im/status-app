import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls

StatusListItem {
    id: root

    property bool isInteractive: false
    property bool copyButtonEnabled: false
    property bool moreButtonEnabled: false

    signal buttonClicked()
    signal copyClicked()

    QtObject {
        id: d
        readonly property var timer: Timer {}
    }

    sensor.enabled: isInteractive
    statusListItemTitle.customColor: Theme.palette.baseColor1
    statusListItemTitle.font.pixelSize: Theme.additionalTextSize
    statusListItemTitle.lineHeightMode: Text.FixedHeight
    statusListItemTitle.lineHeight: 18
    statusListItemSubTitle.customColor: Theme.palette.directColor1
    statusListItemSubTitle.textFormat: Qt.RichText
    statusListItemSubTitle.lineHeightMode: Text.FixedHeight
    statusListItemSubTitle.lineHeight: 22
    statusListItemSubTitle.elide: Text.ElideNone
    statusListItemSubTitle.wrapMode: Text.WrapAnywhere

    // Expose subtitle value for accessibility/testing
    Accessible.role: Accessible.ListItem
    Accessible.name: root.title + ": " + root.subTitle
    color: {
        if (isInteractive && (sensor.containsMouse || root.highlighted)) {
            return Theme.palette.baseColor2
        }
        return StatusColors.transparent
    }
    components: [
        StatusRoundButton {
            width: 32
            height: 32
            radius: 8
            visible: moreButtonEnabled && isInteractive  && root.sensor.containsMouse
            type: StatusRoundButton.Type.Quinary
            icon.name: "more"
            icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
            icon.hoverColor: Theme.palette.primaryColor3
            onClicked: root.buttonClicked()
        },
        StatusRoundButton {
            id: copyButton
            property bool checked: false
            width: 32
            height: 32
            radius: 8
            visible: copyButtonEnabled && isInteractive  && root.sensor.containsMouse
            type: StatusRoundButton.Type.Quinary
            icon.name: copyButton.checked ? "tiny/checkmark": "copy"
            icon.color: copyButton.checked ? Theme.palette.successColor1 : hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
            icon.hoverColor: copyButton.checked ? Theme.palette.successColor1 : Theme.palette.primaryColor3
            onClicked: {
                copyButton.checked = true
                root.copyClicked()
                d.timer.setTimeout(function() {
                    copyButton.checked = false
                }, 1500)
            }
        }
    ]
}
