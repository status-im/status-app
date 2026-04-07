pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

StatusButton {
    id: root

    property color bgColor: Theme.palette.baseColor2
    property color contentColor: Theme.palette.baseColor1
    property int type: StatusPickerButton.PickerType.Next

    /*!
       \qmlproperty StatusAssetSettings StatusPickerButton::asset
       This property holds the image settings information.
    */
    asset {
        width: 20
        height: 20
        imgIsIdenticon: false
    }

    enum PickerType {
        Next,
        Down
    }

    property bool isError

    horizontalPadding: 16
    verticalPadding: 3
    spacing: 4
    icon.width: 16
    icon.height: 16
    background: Rectangle {
        radius: 8
        color: root.bgColor
        border.color: Theme.palette.dangerColor1
        border.width: root.isError ? 1 : 0
    }
    opacity: !root.interactive || !root.enabled ? 0.5 : 1
    contentItem: RowLayout {
        spacing: root.spacing
        StatusIcon {
            icon: "tiny/chevron-down"
            visible: root.type === StatusPickerButton.PickerType.Down
            color: !Qt.colorEqual(root.contentColor, Theme.palette.baseColor1) ? root.contentColor : Theme.palette.directColor1
            width: root.icon.width
            height: root.icon.height
        }
        StatusRoundedImage {
            visible: root.asset.name.toString() !== ""
            Layout.preferredWidth: root.asset.width
            Layout.preferredHeight: root.asset.height
            image.source: root.asset.name
        }
        StatusBaseText {
            Layout.fillWidth: true
            font: root.font
            color: root.contentColor
            text: root.text
            elide: Text.ElideRight
        }
        StatusIcon {
            icon: "next"
            visible: root.type === StatusPickerButton.PickerType.Next
            color: !Qt.colorEqual(root.contentColor, Theme.palette.baseColor1) ? root.contentColor : Theme.palette.directColor1
            width: root.icon.width
            height: root.icon.height
        }
    }
}
