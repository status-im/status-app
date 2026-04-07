pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

TabButton {
    id: statusIconTabButton

    property string name: ""
    property bool highlighted: false

    property alias identicon: identicon

    implicitWidth: 40
    implicitHeight: 40

    icon.height: 24
    icon.width: 24
    icon.color: Theme.palette.baseColor1

    hoverEnabled: enabled

    contentItem: Item {
        anchors.fill: parent
        StatusSmartIdenticon {
            id: identicon
            anchors.centerIn: parent
            loading: statusIconTabButton.icon.name === "loading"
            asset.isImage: loading || statusIconTabButton.icon.source.toString() !== ""
            asset.name: asset.isImage ?
                        statusIconTabButton.icon.source : statusIconTabButton.icon.name
            asset.width: asset.isImage ? 28 : statusIconTabButton.icon.width
            asset.height: asset.isImage ? 28 : statusIconTabButton.icon.height
            asset.color: (statusIconTabButton.hovered || highlighted || statusIconTabButton.checked) ? Theme.palette.primaryColor1 : statusIconTabButton.icon.color
            asset.isLetterIdenticon: statusIconTabButton.name !== "" && !asset.isImage
            asset.charactersLen: 1
            asset.useAcronymForLetterIdenticon: false
            name: statusIconTabButton.name
        }
    }

    background: Rectangle {
        color: hovered || highlighted || ((!!icon.source.toString() || !!name) && checked) ? Theme.palette.primaryColor3 : "transparent"
        border.color: Theme.palette.primaryColor1
        border.width: (!!icon.source.toString() || !!name) && checked ? 1 : 0
        radius: statusIconTabButton.width / 2
    }

    HoverHandler {
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }
}
