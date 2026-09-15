import QtQuick
import Qt5Compat.GraphicalEffects

Image {
    id: root

    fillMode: Image.PreserveAspectCrop

    property bool rounded: true

    layer.enabled: rounded
    layer.effect: OpacityMask {
        maskSource: Item {
            width: root.width
            height: root.height
            Rectangle {
                anchors.centerIn: parent
                width: root.width
                height: root.height
                radius: Math.min(width, height)
            }
        }
    }
}
