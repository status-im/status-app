import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme

import utils

Control {
    id: root

    property var overview

    implicitHeight: 115

    contentItem: Loader {
        sourceComponent: root.overview && root.overview.isAllAccounts ? multipleAccountsGradient : singleAccountGradient

        Component {
            id: singleAccountGradient
            Rectangle {
                gradient: Gradient {
                    GradientStop { position: 0.0; color: overview && overview.colorId ? StatusColors.alphaColor(Utils.getColorForId(root.Theme.palette, overview.colorId), 0.1) : "" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
        Component {
            id: multipleAccountsGradient
            Item {
                Rectangle {
                    id: base
                    anchors.fill: parent
                    Component.onCompleted: {
                        let splitWords = root.overview.colorIds.split(';')

                        var stops = []
                        let numOfColors = splitWords.length
                        let gap =  1/splitWords.length
                        let startPosition = gap
                        for (const word of splitWords) {
                            stops.push(stopComponent.createObject(base, {"position":startPosition, "color": StatusColors.alphaColor(Utils.getColorForId(root.Theme.palette, word), 0.1)}))
                            startPosition += gap
                        }
                        gradient.stops = stops
                    }

                    gradient: Gradient {
                        id: gradient
                        orientation: Gradient.Horizontal
                    }

                    // fading out from the top down: computed by the shader on
                    // this item's layer, with no second layer for a mask
                    layer.enabled: true
                    layer.effect: StatusEdgeFadeEffect {
                        bottomFade: base.height
                    }
                }
            }
        }
        Component {
            id:stopComponent
            GradientStop {}
        }
    }
}
