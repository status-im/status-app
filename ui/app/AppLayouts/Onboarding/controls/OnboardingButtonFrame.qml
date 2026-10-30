pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme

Frame {
    id: root

    padding: 0

    background: Rectangle {
        id: background
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: 12
        color: Theme.palette.background
    }

    // clip the content to the background's corners: computed by the shader
    // on the frame's layer, with no second layer for a mask
    layer.enabled: true
    layer.effect: StatusRoundedCornersEffect {
        radius: background.radius
    }
}
