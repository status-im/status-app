import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Item {
    id: root

    property ObjectModel customButtons

    readonly property alias closeButton: closeButton
    readonly property alias infoButton: infoButton

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    QtObject {
        id: d
        readonly property int buttonSize: 32
        readonly property int iconSize: 24
    }

    RowLayout {
        id: layout

        anchors.fill: parent

        Repeater {
            model: root.customButtons
            onItemAdded: function(index, item) {
                item.Layout.fillHeight = true
                item.Layout.preferredHeight = d.buttonSize
                item.Layout.preferredWidth = d.buttonSize
            }
        }

        StatusFlatRoundButton {
            id: infoButton

            Layout.fillHeight: true
            Layout.preferredHeight: d.buttonSize
            Layout.preferredWidth: d.buttonSize

            visible: false

            type: StatusFlatRoundButton.Type.Secondary
            icon.name: "info"
            icon.color: Theme.palette.directColor1
            icon.width: d.iconSize
            icon.height: d.iconSize
        }

        StatusFlatRoundButton {
            id: closeButton
            objectName: "headerActionsCloseButton"

            Layout.fillHeight: true
            Layout.preferredHeight: d.buttonSize
            Layout.preferredWidth: d.buttonSize

            type: StatusFlatRoundButton.Type.Secondary
            icon.name: "close"
            icon.color: Theme.palette.directColor1
            icon.width: d.iconSize
            icon.height: d.iconSize
        }
    }
}
