pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

Control {
    id: root

    property string title
    property string subTitle
    property string icon
    property alias checked: switchItem.checked

    signal toggled

    padding: 4

    contentItem: RowLayout {
        spacing: Theme.padding

        StatusRoundIcon {
            asset.name: root.icon
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                visible: !!text
                color: Theme.palette.directColor1
                elide: Text.ElideRight
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: root.subTitle
                visible: !!text
                color: Theme.palette.baseColor1
                lineHeight: 1.2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }

        StatusSwitch {
            id: switchItem
            objectName: "switchItem"
            padding: 0

            onToggled: root.toggled()
        }
    }
}
