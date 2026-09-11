import QtQuick
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme

/*!
   \qmltype LoadingSkeletonGroup
   \inherits Item
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Renders an arbitrary arrangement of LoadingSkeletonTile shapes with a
   single shared shimmer sweep.

   Use this for creation-time skeleton screens instead of many LoadingComponent
   instances: tiles are plain rectangles and the whole group costs one effect
   pass, where every LoadingComponent carries its own OpacityMask and animator.

   Example:

   \qml
    LoadingSkeletonGroup {
        width: 200
        height: 60

        Row {
            spacing: 8
            LoadingSkeletonTile { width: 40; height: 40; radius: 20 }
            Column {
                spacing: 6
                LoadingSkeletonTile { width: 120; height: 14 }
                LoadingSkeletonTile { width: 80; height: 12 }
            }
        }
    }
   \endqml
*/
Item {
    id: root

    default property alias contentData: shapesContainer.data

    // The effect is backed by FBOs the size of the whole group; beyond GPU
    // texture limits it silently paints nothing (a very tall group — e.g. a
    // paging placeholder — would white out entirely). Past this height the
    // tiles render plain, without the sweep.
    readonly property bool shimmerEnabled: root.visible && root.height > 0
                                           && root.height <= 6000

    Item {
        id: shapesContainer
        anchors.fill: parent
    }

    // The animated sweep band, materialized only while the group is visible.
    // It is masked by the shapes so the shimmer only shows on the tiles.
    Item {
        id: sweepContainer
        anchors.fill: parent
        visible: false

        Loader {
            anchors.fill: parent
            active: root.shimmerEnabled
            sourceComponent: Rectangle {
                id: sweep

                width: 100
                height: 2 * parent.height
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
                    easing.type: Easing.Linear
                    loops: Animation.Infinite
                    running: true
                    from: -sweep.width
                    to: sweep.parent.width + sweep.width
                    duration: 1000
                }

                Connections {
                    target: sweep.parent
                    function onWidthChanged() { sweepAnimator.restart() }
                }
            }
        }
    }

    // Loader-gated, not just hidden: the mask's source bindings keep its
    // layer textures alive even while the effect item is invisible.
    Loader {
        anchors.fill: parent
        active: root.shimmerEnabled

        sourceComponent: OpacityMask {
            source: sweepContainer
            maskSource: shapesContainer
        }
    }
}
