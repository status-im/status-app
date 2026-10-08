import QtQuick
import QtQuick.Effects

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

    // apply rounded corners mask
    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        maskSource: Rectangle {
            parent: root
            layer.enabled: true
            visible: false
            width: root.width
            height: root.height
            radius: root.radius
        }
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
