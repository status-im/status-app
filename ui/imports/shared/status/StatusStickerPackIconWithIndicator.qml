import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

import utils
import shared.panels

Item {
    id: root

    property bool selected: false
    property bool useIconInsteadOfImage: false
    property url source: Assets.svg("history")
    signal clicked

    implicitHeight: 28
    implicitWidth: 28

    RoundedImage {
        visible: !useIconInsteadOfImage
        id: iconImage
        width: parent.width
        height: parent.height
        source: root.source
        onClicked: {
            root.clicked()
        }
    }

    RoundedIcon {
        id: iconIcon
        visible: useIconInsteadOfImage
        width: parent.width
        height: parent.height
        iconWidth: 6
        color: Theme.palette.darkGrey
        source: root.source
        onClicked: {
            root.clicked()
        }
    }

    Rectangle {
        visible: root.selected
        width: parent.width
        height: 2
        radius: 1
        color: Theme.palette.primaryColor1
        y: root.y + root.height + 6
    }
}
