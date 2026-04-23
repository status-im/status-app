import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme

/*!
   \qmltype LoadingComponent
   \inherits Control
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief A component that can be used to adding a loading state to a widget
   Example:

   \qml
    StatusBaseText {
    id: root
        LoadingComponent {
            anchors.fill: parent
            radius: 8
        }
    }
   \endqml

   For a list of components available see StatusQ.
*/

Control {
    id: root

    /*!
        \qmlproperty bool LoadingComponent::radius
        This property lets user set custom radius
    */
    property int radius: 4

    background: null

    contentItem: Item {
        property real contentItemWidth: 0
        onWidthChanged: {
            contentItemWidth = width
            animation.restart()
        }
        Rectangle {
            id: rect
            anchors.fill: parent
            color: Theme.palette.statusLoadingHighlight
            radius: root.radius
            visible: false

            LinearGradient {
                id: gradient
                width: 100
                height: 2*parent.height
                x: -width
                y: -height/4
                start: Qt.point(0, height)
                end: Qt.point(width, height)
                gradient: Gradient {
                    GradientStop { position: 0.2; color: "transparent"}
                    GradientStop { position: 0.5; color: Theme.palette.statusLoadingHighlight2 }
                    GradientStop { position: 0.8; color: "transparent"}
                }
                rotation: 20
                XAnimator on x {
                    id: animation
                    easing.type: Easing.Linear
                    loops: Animation.Infinite
                    running: root.visible
                    from: -gradient.width
                    to: contentItem.contentItemWidth + gradient.width
                    duration: 1000
                    easing.period: 2
                }
            }
        }

        OpacityMask {
            anchors.fill: rect
            source: rect
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.radius
            }
        }
    }
}

