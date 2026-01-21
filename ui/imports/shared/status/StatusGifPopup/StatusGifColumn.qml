import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import utils
import shared.stores

Column {
    id: root
    spacing: 8

    property alias gifList: repeater
    property int gifWidth: 0
    property string lastHoveredId

    property var toggleFavorite: function () {}
    property var isFavorite: function () {}
    property var addToRecentsGif: function () {}

    signal gifHovered(string id)
    signal gifSelected(string url)

    Repeater {
        id: repeater

        delegate: Rectangle {
            id: thumb
            property alias hovered: mouseArea.containsMouse
            onHoveredChanged: {
                if (hovered) {
                    root.gifHovered(model.id)
                }
            }

            height: animation.status != Image.Ready ? loader.height : animation.height
            width: root.gifWidth
            color: Theme.palette.background

            Rectangle {
                id: loader
                height: 100
                width: root.gifWidth
                visible: animation.status != Image.Ready
                radius: Theme.radius
                rotation: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#E6EEF2" }
                }
            }

            StatusBaseButton {
                id: starButton
                property bool favorite: root.isFavorite(model.id)

                type: StatusFlatRoundButton.Type.Secondary
                textColor: hovered || favorite ? Theme.palette.miscColor7 : Theme.palette.secondaryText
                icon.name: favorite ? "star-icon" : "star-icon-outline"
                icon.width:  (14/104) * thumb.width
                icon.height: (13/104) * thumb.width
                topPadding: (6/104) * thumb.width
                rightPadding: (6/104) * thumb.width
                bottomPadding: (6/104) * thumb.width
                leftPadding: (6/104) * thumb.width
                normalColor: "transparent"
                visible: !loader.visible && model.id === root.lastHoveredId
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                z: 1
                onClicked: {
                    root.toggleFavorite(model)
                    favorite = !favorite
                }
                onHoveredChanged: {
                    if (hovered) {
                        root.gifHovered(model.id)
                    }
                }
                StatusToolTip {
                    id: statusToolTip
                    text: starButton.favorite ?
                        qsTr("Remove from favorites") :
                        qsTr("Add to favorites")
                    visible: starButton.hovered
                }
            }

            AnimatedImage {
                id: animation
                visible: animation.status == Image.Ready
                source: model.tinyUrl
                width: root.gifWidth
                fillMode: Image.PreserveAspectFit
                z: 0
                layer.enabled: true
                layer.effect: OpacityMask {
                    opacity: model.id === root.lastHoveredId ? 0.6 : 1
                    maskSource: Rectangle {
                        width: animation.width
                        height: animation.height
                        radius: Theme.radius
                    }
                }
            }

            StatusMouseArea {
                id: mouseArea
                objectName: "gifMouseArea_" + index
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.addToRecentsGif(model.id)
                    root.gifSelected(model.url)
                }
            }
        }
    }
}
