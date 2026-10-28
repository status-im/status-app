import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import utils

Rectangle {
    id: root
    signal clicked
    property bool noMouseArea: false
    property bool noHover: false
    property alias showLoadingIndicator: imgStickerPackThumb.showLoadingIndicator
    property alias source: imgStickerPackThumb.source
    property alias fillMode: imgStickerPackThumb.fillMode

    radius: width / 2

    width: 24
    height: 24
    color: Theme.palette.background

    // round the corners: computed by the shader on this item's layer, with no
    // second layer for a mask
    layer.enabled: true
    layer.effect: StatusRoundedCornersEffect {
        radius: root.radius
    }

    ImageLoader {
        id: imgStickerPackThumb
        noMouseArea: root.noMouseArea
        noHover: root.noHover
        opacity: 1
        smooth: false
        radius: root.radius
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
