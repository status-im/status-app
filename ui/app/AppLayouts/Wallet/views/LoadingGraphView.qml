import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls

import utils
import shared.views
import shared.controls

import "../stores"

Loader {
    id: root
    active: false
    sourceComponent: Item {
        Image {
            id: graphMask
            anchors.fill: parent
            source: Assets.svg("mask/dummyLineGraph")
            sourceSize: Qt.size(parent.width, parent.height)
            smooth: true
            visible: false
            cache: false
        }

        // The loading skeleton's shimmer (as LoadingSkeletonTile draws it)
        // shown through the graph's outline, in one shader pass: the
        // outline's own texture is the mask.
        ShaderEffect {
            id: sweep

            anchors.fill: parent

            readonly property Item mask: graphMask
            readonly property size itemSize: Qt.size(width, height)
            readonly property real pixelRatio: Screen.devicePixelRatio
            readonly property color color: Theme.palette.statusLoadingHighlight
            readonly property color highlightColor: Theme.palette.statusLoadingHighlight2
            property real phase: 0

            fragmentShader: "qrc:/StatusQ/shaders/skeletonmask.frag.qsb"

            Loader {
                active: sweep.visible
                sourceComponent: UniformAnimator {
                    target: sweep
                    uniform: "phase"
                    from: 0
                    to: 1
                    duration: 1000
                    loops: Animation.Infinite
                    running: true
                }
            }
        }
    }
}
