import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Components.private
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import utils
import shared.stores

Column {
    id: root
    spacing: Theme.defaultHalfPadding

    property alias gifList: repeater
    property int gifWidth: 0
    property string lastHoveredId

    property var toggleFavorite: function (item) {}
    property var isFavorite: function (id) {}
    property var addToRecentsGif: function (id) {}

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

                type: StatusBaseButton.Type.Normal
                size: StatusBaseButton.Size.Tiny
                textColor: hovered || favorite ? Theme.palette.miscColor7 : StatusColors.grey4
                icon.name: favorite ? "star-icon" : "star-icon-outline"
                normalColor: StatusColors.alphaColor(StatusColors.black, 0.4)
                hoverColor: Theme.palette.hoverColor(normalColor)
                visible: !loader.visible
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
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
                tooltip.text: favorite ? qsTr("Remove from favorites")
                                       : qsTr("Add to favorites")
            }

            // Rounded in the pass drawing the GIF's own texture. Decoded at
            // its native size, shown at the column's width and the GIF's
            // aspect ratio, as before.
            RoundedAnimatedImage {
                id: animation

                visible: animation.status == Image.Ready
                source: model.tinyUrl
                asynchronous: true
                width: root.gifWidth
                height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                fillMode: Image.PreserveAspectFit
                radius: Theme.radius
                z: 0
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
