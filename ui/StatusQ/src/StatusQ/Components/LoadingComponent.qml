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
        id: content

        Rectangle {
            id: rect
            anchors.fill: parent
            color: Theme.palette.statusLoadingHighlight
            radius: root.radius
            visible: false // used only as the OpacityMask source

            // The animated sweep is materialized only while the placeholder is
            // effectively visible. When hidden, the Loader is inactive so no
            // animation object exists and the render thread can park instead of
            // repainting the whole scene at 60fps for a hidden shimmer.
            Loader {
                id: sweepLoader
                width: rect.width
                height: rect.height
                active: root.visible
                sourceComponent: sweepComponent
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

    // Native Rectangle gradient sweep — no Qt5Compat LinearGradient (which is an
    // extra ShaderEffectSource pass). Only the rounded OpacityMask pass remains.
    // The sweep reads its geometry from `parent` (the Loader) so it needs no
    // reference to outer-scope ids.
    Component {
        id: sweepComponent

        Rectangle {
            id: sweep
            objectName: "shimmerSweep"

            width: 100
            height: 2 * sweep.parent.height
            x: -width
            y: -height / 4
            rotation: 20

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.2; color: StatusColors.transparent }
                GradientStop { position: 0.5; color: Theme.palette.statusLoadingHighlight2 }
                GradientStop { position: 0.8; color: StatusColors.transparent }
            }

            XAnimator on x {
                id: sweepAnimator
                objectName: "shimmerAnimator"
                easing.type: Easing.Linear
                loops: Animation.Infinite
                running: true
                from: -sweep.width
                to: sweep.parent.width + sweep.width
                duration: 1000
            }

            // Restart the sweep when the placeholder is resized, matching the
            // original behaviour (avoids a stale sweep span for one cycle).
            Connections {
                target: sweep.parent
                function onWidthChanged() { sweepAnimator.restart() }
            }
        }
    }
}
